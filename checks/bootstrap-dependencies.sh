set -euo pipefail
restore=$1 node_bin=$2 pi=$3 probe=$4 fixture=$5
export PATH="$node_bin:$PATH"
export HOME="$TMPDIR/dependencies" npm_config_offline=true
ext="$HOME/.pi/agent/extensions/herdr-codemode"
mkdir -p "$ext" "$HOME/personal/home/references" "$TMPDIR/fixture-package" "$TMPDIR/probe"
touch "$HOME/personal/home/references/personal.md"
bash "$fixture" "$ext" "$TMPDIR/fixture-package"
cp "$ext/package-lock.json" "$TMPDIR/valid-lock"
run_probe() {
  env -i HOME="$TMPDIR/probe" PI_CODING_AGENT_DIR="$TMPDIR/probe" PI_OFFLINE=1 PATH="$PATH" \
    node "$probe" "$pi" "$HOME/.pi/agent" "$TMPDIR/probe"
}

# The very same Pi loader used by the first-boot command must reject the clean clone.
if run_probe > "$TMPDIR/missing.log" 2>&1; then exit 41; fi
grep -F bootstrap-dep "$TMPDIR/missing.log"
# An npm failure must not publish anything or alter the manifest or Agent source.
printf 'broken lock\n' > "$ext/package-lock.json"
if "$restore" > "$TMPDIR/failure.log" 2>&1; then exit 42; fi
grep -F 'npm ci falhou' "$TMPDIR/failure.log"
[[ ! -e "$ext/node_modules" && -z "$(find "$ext" -name '.pi-deps.*' -print -quit)" ]]
grep -Fx 'broken lock' "$ext/package-lock.json"
cp "$TMPDIR/valid-lock" "$ext/package-lock.json"
"$restore"
run_probe
cmp "$TMPDIR/valid-lock" "$ext/package-lock.json"

printf local > "$ext/node_modules/local-marker"
printf '// local edit\n' >> "$ext/index.ts"
# With a broken lock, a repeated npm ci would fail; it must not run at all.
printf 'broken lock\n' > "$ext/package-lock.json"
"$restore"
run_probe
grep -Fx local "$ext/node_modules/local-marker"
grep -Fx '// local edit' "$ext/index.ts"
[[ ! -e "$HOME/clones" ]]

mv "$ext/node_modules/bootstrap-dep" "$ext/preserved-package"
if "$restore" > "$TMPDIR/preservation.log" 2>&1; then exit 43; fi
grep -F 'dependências existentes inutilizáveis' "$TMPDIR/preservation.log"
grep -Fx local "$ext/node_modules/local-marker"
test -f "$ext/preserved-package/index.js"
echo 'PASS clean npm ci, actual Pi import, failed install/retry, idempotence and preservation'
