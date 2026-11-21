set -euo pipefail
umask 077
extension="$HOME/.pi/agent/extensions/herdr-codemode"
[[ -d "$extension" ]] || exit 0

fail() {
  echo "Pi: herdr-codemode: $*" >&2
  exit 1
}

conflict() {
  echo 'Pi: herdr-codemode: node_modules gerenciado alterado ou incompleto ou destino não é um diretório real; destino preservado. Mova-o para um backup para permitir a instalação.' >&2
  exit 78
}

# Serialize cooperating provisioners without writing to the Git checkout.
exec 9< "$extension"
flock -n 9 || fail 'outra instalação em andamento; tente novamente.'
integrity() { node "$PI_DEPENDENCY_INTEGRITY" "$@"; }

tree="$extension/node_modules"
receipt=.dots-dependencies.json
installed=
previous=
if [[ -e "$tree" || -L "$tree" ]]; then
  [[ ! -L "$tree" && -d "$tree" ]] || conflict
  previous=$(stat -c '%d:%i' -- "$tree")
  if [[ -e "$tree/$receipt" || -L "$tree/$receipt" ]]; then
    installed=$(integrity inspect "$extension") || conflict
  fi
fi
wanted=$(integrity inputs "$extension") || fail 'manifesto ou lockfile ausente; checkout preservado.'
[[ "$installed" != "$wanted" ]] || exit 0

state="${XDG_STATE_HOME:-$HOME/.local/state}/pi-extension-deps"
mkdir -p -- "$state"
[[ "$(stat -c %d -- "$state/")" == "$(stat -c %d -- "$extension/")" ]] ||
  fail 'diretório de estado e extensão precisam estar no mesmo filesystem para troca atômica.'
stage=$(mktemp -d -- "$state/transaction.XXXXXX")
keep=0
trap 'if (( ! keep )); then rm -rf -- "$stage"; fi' EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
cp -- "$extension/package.json" "$extension/package-lock.json" "$stage/"
(
  cd -- "$stage"
  npm ci --omit=dev --ignore-scripts --no-audit --no-fund --no-progress \
    --userconfig="$stage/user.npmrc" --globalconfig="$stage/global.npmrc"
) || fail 'npm ci falhou; nenhum node_modules foi publicado.'
record=$(integrity record "$stage") || fail 'dependências instaladas não correspondem ao lockfile.'
(
  cd -- "$stage"
  node --input-type=module <<'JS'
import { existsSync, readFileSync } from 'node:fs';
const { dependencies } = JSON.parse(readFileSync('package.json', 'utf8'));
for (const name of Object.keys(dependencies)) {
  if (!existsSync(new URL(import.meta.resolve(name)))) throw new Error(`Missing dependency: ${name}`);
}
JS
) || fail 'dependências instaladas não resolvem; nenhum node_modules foi publicado.'
printf '%s\n' "$record" > "$stage/node_modules/$receipt"

if [[ -n "$installed" ]]; then
  # Recheck after npm, so unrelated writers cannot silently lose edits.
  current=$(integrity inspect "$extension") || conflict
  [[ "$current" == "$installed" ]] || conflict
fi
for file in package.json package-lock.json; do
  cmp -s -- "$extension/$file" "$stage/$file" || fail 'manifestos mudaram durante a instalação; tente novamente.'
done
if [[ -n "$previous" ]]; then
  [[ ! -L "$tree" && "$(stat -c '%d:%i' -- "$tree")" == "$previous" ]] || conflict
  if [[ -z "$installed" ]]; then
    [[ ! -e "$tree/$receipt" && ! -L "$tree/$receipt" ]] || conflict
    if adopted=$(integrity matches "$extension" "$stage/node_modules"); then
      printf '%s\n' "$adopted" > "$stage/adopted.json"
      cmp -s -- "$extension/package-lock.json" "$stage/package-lock.json" &&
        cmp -s -- "$extension/package.json" "$stage/package.json" ||
        fail 'manifestos mudaram durante a adoção; tente novamente.'
      [[ ! -L "$tree" && "$(stat -c '%d:%i' -- "$tree")" == "$previous" ]] || conflict
      ln -T -- "$stage/adopted.json" "$tree/$receipt" ||
        fail 'não foi possível registrar a adoção; dependências preservadas.'
      echo 'Pi: node_modules existente de herdr-codemode verificado e adotado.'
      exit 0
    fi
    echo 'Pi: node_modules existente diverge da referência; a árvore original ficará no backup.'
  fi
  # Keep the exchanged tree even if a non-cooperating writer changed it
  # between inspection and exchange. Do not garbage collect user data.
  keep=1
  if ! mv -T --exchange --no-copy -- "$stage/node_modules" "$tree"; then
    keep=0
    fail 'não foi possível trocar node_modules atomicamente.'
  fi
  printf '%s\n' 'Pi: dependências anteriores preservadas em:' "$stage/node_modules"
else
  mv -T --no-copy --no-clobber -- "$stage/node_modules" "$tree" ||
    fail 'não foi possível publicar node_modules.'
  [[ ! -e "$stage/node_modules" ]] || conflict
fi
echo 'Pi: dependências locais de herdr-codemode prontas.'
