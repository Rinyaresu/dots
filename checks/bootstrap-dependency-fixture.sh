set -euo pipefail
extension=$1 work=$2 version=${3:-1.0.0}
mkdir -p "$extension" "$work"
# A real npm tarball, with no registry or private Agent access.
printf '{"name":"bootstrap-dep","version":"%s","type":"module","exports":"./index.js","scripts":{"postinstall":"exit 42"}}\n' "$version" > "$work/package.json"
printf 'export const version = "%s";\n' "$version" > "$work/index.js"
(cd "$work"; npm pack --ignore-scripts --silent)
tarball="$work/bootstrap-dep-$version.tgz"
printf '{"name":"bootstrap-fixture","version":"1.0.0","dependencies":{"bootstrap-dep":"file:%s"}}\n' "$tarball" > "$extension/package.json"
(cd "$extension"; npm install --package-lock-only --ignore-scripts --no-audit --no-fund)
printf '%s\n' 'import { version } from "bootstrap-dep";' \
  'if (version !== process.env.PI_FIXTURE_VERSION) throw new Error("wrong dependency version");' \
  'export default () => {};' > "$extension/index.ts"
chmod a+r "$tarball"
