set -euo pipefail
restore=$1 node_bin=$2 pi=$3 probe=$4 fixture=$5
export PATH="$node_bin:$PATH"
export HOME="$TMPDIR/dependencies" npm_config_offline=true
export XDG_STATE_HOME="$HOME/.state"
ext="$HOME/.pi/agent/extensions/herdr-codemode"
tree="$ext/node_modules"
dist="$TMPDIR/fixture-package"
state="$XDG_STATE_HOME/pi-extension-deps"
mkdir -p "$ext" "$HOME/personal/home/references" "$TMPDIR/probe"
touch "$HOME/personal/home/references/personal.md"
bash "$fixture" "$ext" "$dist" 1.0.0
run_probe() {
  env -i HOME="$TMPDIR/probe" PI_CODING_AGENT_DIR="$TMPDIR/probe" PI_OFFLINE=1 PATH="$PATH" \
    PI_FIXTURE_VERSION="$1" node "$probe" "$pi" "$HOME/.pi/agent" "$TMPDIR/probe"
}
expect_failure() {
  if "$restore" > "$TMPDIR/failure.log" 2>&1; then exit 42; fi
  grep -F "$1" "$TMPDIR/failure.log" || { tail -30 "$TMPDIR/failure.log" >&2; return 1; }
}
inode() { stat -c '%d:%i' -- "$1"; }

if run_probe 1.0.0 > "$TMPDIR/missing.log" 2>&1; then exit 41; fi
grep -F bootstrap-dep "$TMPDIR/missing.log"
cp "$ext/package-lock.json" "$TMPDIR/valid-lock"
printf 'broken lock\n' > "$ext/package-lock.json"
expect_failure 'npm ci falhou'
[[ ! -e "$tree" && -z "$(find "$state" -mindepth 1 -print -quit)" ]]
grep -Fx 'broken lock' "$ext/package-lock.json"
cp "$TMPDIR/valid-lock" "$ext/package-lock.json"
(
  flock -n 8
  expect_failure 'outra instalação em andamento'
  [[ ! -e "$tree" ]]
) 8< "$ext"
"$restore"
run_probe 1.0.0
first=$(inode "$tree")
cmp "$TMPDIR/valid-lock" "$ext/package-lock.json"

# If npm runs again it cannot fetch the file dependency from this empty cache.
mv "$dist/bootstrap-dep-1.0.0.tgz" "$dist/v1.saved"
export npm_config_cache="$TMPDIR/empty-cache"
[[ -z "$("$restore" 2>&1)" && "$(inode "$tree")" == "$first" ]]
[[ ! -e "$npm_config_cache" ]]
mv "$dist/v1.saved" "$dist/bootstrap-dep-1.0.0.tgz"

bash "$fixture" "$TMPDIR/second" "$dist" 2.0.0
cp "$TMPDIR/second/"package*.json "$ext/"
printf '// local edit\n' >> "$ext/index.ts"
export npm_config_cache="$TMPDIR/update-cache"
mv "$dist/bootstrap-dep-2.0.0.tgz" "$dist/v2.saved"
expect_failure 'npm ci falhou'
[[ "$(inode "$tree")" == "$first" ]]
run_probe 1.0.0
[[ -z "$(find "$state" -mindepth 1 -print -quit)" ]]

mv "$dist/v2.saved" "$dist/bootstrap-dep-2.0.0.tgz"
"$restore"
second=$(inode "$tree")
[[ "$second" != "$first" ]]
backup=$(find "$state" -mindepth 2 -maxdepth 2 -name node_modules)
[[ "$(inode "$backup")" == "$first" ]]
grep -F 'version = "1.0.0"' "$backup/bootstrap-dep/index.js"
run_probe 2.0.0
grep -Fx '// local edit' "$ext/index.ts"
[[ ! -e "$HOME/clones" ]]

# Correct version in the installed manifest is not enough: detect changed bytes
# and missing files, with and without a new lockfile.
cp "$tree/bootstrap-dep/index.js" "$TMPDIR/original"
printf '// manual edit\n' >> "$tree/bootstrap-dep/index.js"
expect_failure 'alterado ou incompleto'
grep -Fx '// manual edit' "$tree/bootstrap-dep/index.js"
bash "$fixture" "$TMPDIR/third" "$dist" 3.0.0
cp "$TMPDIR/third/"package*.json "$ext/"
expect_failure 'alterado ou incompleto'
grep -Fx '// manual edit' "$tree/bootstrap-dep/index.js"
cp "$TMPDIR/original" "$tree/bootstrap-dep/index.js"
mv "$tree/bootstrap-dep" "$ext/preserved-package"
expect_failure 'alterado ou incompleto'
[[ "$(inode "$tree")" == "$second" && ! -e "$tree/bootstrap-dep" ]]
test -f "$ext/preserved-package/index.js"

# Recreate a legacy install using npm install, not the bootstrap.
mv "$tree" "$ext/preserved-tree"
export XDG_STATE_HOME="$HOME/.migration-state"
state="$XDG_STATE_HOME/pi-extension-deps"
(
  cd "$ext"
  umask 022
  npm install --omit=dev --ignore-scripts --no-audit --no-fund
)
receipt="$tree/.dots-dependencies.json"
legacy=$(inode "$tree")
test ! -e "$receipt"
"$restore" > "$TMPDIR/adoption.log"
grep -F 'verificado e adotado' "$TMPDIR/adoption.log"
[[ -f "$receipt" && "$(inode "$tree")" == "$legacy" ]]
[[ -z "$(find "$state" -mindepth 1 -print -quit)" ]]
run_probe 3.0.0
[[ -z "$("$restore" 2>&1)" && "$(inode "$tree")" == "$legacy" ]]

# A differing legacy tree must not be certified or discarded. Make the
# reference unavailable first to exercise preservation and retry.
mv "$tree" "$ext/adopted-tree"
(
  cd "$ext"
  npm install --omit=dev --ignore-scripts --no-audit --no-fund
)
printf '// local dependency edit\n' >> "$tree/bootstrap-dep/index.js"
ln -s bootstrap-dep/index.js "$tree/local-link"
cp -a "$tree" "$TMPDIR/legacy-copy"
legacy=$(inode "$tree")
export npm_config_cache="$TMPDIR/migration-cache"
mv "$dist/bootstrap-dep-3.0.0.tgz" "$dist/v3.saved"
expect_failure 'npm ci falhou'
[[ "$(inode "$tree")" == "$legacy" && ! -e "$receipt" ]]
diff -r --no-dereference "$tree" "$TMPDIR/legacy-copy"
[[ -z "$(find "$state" -mindepth 1 -print -quit)" ]]
mv "$dist/v3.saved" "$dist/bootstrap-dep-3.0.0.tgz"
"$restore" > "$TMPDIR/migration.log"
grep -F 'a árvore original ficará no backup' "$TMPDIR/migration.log"
backup=$(find "$state" -mindepth 2 -maxdepth 2 -name node_modules)
[[ "$(inode "$backup")" == "$legacy" && "$(inode "$tree")" != "$legacy" ]]
diff -r --no-dereference "$backup" "$TMPDIR/legacy-copy"
test ! -e "$backup/.dots-dependencies.json"
run_probe 3.0.0
migrated=$(inode "$tree")
export npm_config_cache="$TMPDIR/unused-migration-cache"
[[ -z "$("$restore" 2>&1)" && "$(inode "$tree")" == "$migrated" ]]
[[ ! -e "$npm_config_cache" ]]
echo 'PASS clean install, no-op, serialized update, retry, tamper detection, legacy adoption, migration and actual Pi import'
