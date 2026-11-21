set -euo pipefail
umask 077
extension="$HOME/.pi/agent/extensions/herdr-codemode"
[[ -d "$extension" ]] || exit 0

fail() {
  echo "Pi: herdr-codemode: $*" >&2
  exit 1
}

# Only inspect existing dependencies; npm ci would delete that tree first.
resolves() (
  cd -- "$1"
  node --input-type=module <<'JS'
import { existsSync, readFileSync } from 'node:fs';
const { dependencies } = JSON.parse(readFileSync('package.json', 'utf8'));
for (const name of Object.keys(dependencies)) {
  const url = import.meta.resolve(name);
  if (!existsSync(new URL(url))) throw new Error(`Missing dependency: ${name}`);
}
JS
)

if [[ -e "$extension/node_modules" || -L "$extension/node_modules" ]]; then
  resolves "$extension" || fail 'dependências existentes inutilizáveis; preserve ou mova node_modules e reinicie pi-config-restore.service.'
  exit 0
fi

[[ -f "$extension/package.json" && -f "$extension/package-lock.json" ]] || fail 'manifesto ou lockfile ausente; checkout preservado.'
# Stage on the same filesystem, so failures and concurrent writers cannot
# leave a partial node_modules at the final path. Never run npm in the checkout.
stage=$(mktemp -d -- "$extension/.pi-deps.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
cp -- "$extension/package.json" "$extension/package-lock.json" "$stage/"
(
  cd -- "$stage"
  npm ci --omit=dev --ignore-scripts --no-audit --no-fund --no-progress \
    --userconfig="$stage/user.npmrc" --globalconfig="$stage/global.npmrc"
) || fail 'npm ci falhou; nenhum node_modules foi publicado. Confira o journal e tente novamente.'
resolves "$stage" || fail 'dependências instaladas não resolvem; nenhum node_modules foi publicado.'
for file in package.json package-lock.json; do
  cmp -s -- "$extension/$file" "$stage/$file" || fail 'manifestos mudaram durante a instalação; tente novamente.'
done
if ! mv -T --no-copy --no-clobber -- "$stage/node_modules" "$extension/node_modules"; then
  [[ -e "$extension/node_modules" || -L "$extension/node_modules" ]] || fail 'não foi possível publicar node_modules.'
fi
resolves "$extension" || fail 'dependências no destino inutilizáveis; destino preservado.'
echo 'Pi: dependências locais de herdr-codemode prontas.'
