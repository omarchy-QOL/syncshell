#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
destination=${1:-"$root/dist/noctalia"}
export_root=""
if [[ ${1:-} == --export ]]; then
    export_root=${2:-"$root/dist/noctalia-export"}
    destination="$export_root/syncshell"
elif (( $# > 1 )); then
    printf 'usage: assemble.sh [destination] | --export [directory]\n' >&2
    exit 2
fi
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || {
    printf 'only Linux x86_64 has offline validation for this package\n' >&2
    exit 1
}
if [[ -e $destination || -L $destination ]]; then
    [[ ! -L $destination && -f $destination/.syncshell-noctalia-package ]] || {
        printf 'refusing to replace an unowned package directory\n' >&2
        exit 1
    }
fi
mkdir -p -- "$(dirname -- "$destination")"
staging=$(mktemp -d "$(dirname -- "$destination")/.noctalia-build.XXXXXX")
trap 'rm -rf -- "$staging"' EXIT
mkdir -p -- "$staging/hosts" "$staging/bin" "$staging/assets/mono"
cp -a -- "$root/hosts/noctalia" "$staging/hosts/"
cp -- "$root/integrations/noctalia/plugin.toml" "$staging/"
cp -a -- "$root/integrations/noctalia/translations" "$staging/"
cp -a -- "$root/webui" "$staging/"
cp -- "$root"/assets/status-*.svg "$staging/assets/"
cp -- "$root"/assets/mono/status-*.svg "$staging/assets/mono/"
cp -- "$root/assets/LICENSE.md" "$staging/assets/"
cp -- "$root/LICENSE" "$staging/"
mkdir -p -- "$staging/notices"
cp -- "$root/packaging/bundled/LICENSE.golang" "$staging/notices/"
cp -- "$root/hosts/noctalia/README.md" "$staging/README.md"
(
    cd -- "$root/core"
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -buildvcs=false \
        -ldflags='-s -w' -o "$staging/bin/syncshell-core" ./cmd/syncshell-core
    sys_directory=$(go list -m -f '{{.Dir}}' golang.org/x/sys)
    cp -- "$sys_directory/LICENSE" "$staging/notices/LICENSE.x-sys"
)
printf 'linux/amd64\nnoctalia 8240b170dbbbf47b231170a795b24ae9ac7923f6\nplugin-api 31\n' \
    > "$staging/.syncshell-noctalia-package"
python3 "$root/tests/noctalia/package.py" "$staging"
(
    cd -- "$staging"
    # the checksum manifest is excluded from its own inputs
    # shellcheck disable=SC2094
    find . -type f ! -name PACKAGE-SHA256SUMS -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > PACKAGE-SHA256SUMS
)
if [[ -d $destination ]]; then rm -rf -- "$destination"; fi
mv -- "$staging" "$destination"
if [[ -n $export_root ]]; then
    python3 - "$destination/plugin.toml" "$export_root/catalog.toml" <<'PY'
import json
import pathlib
import sys
import tomllib
manifest = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
keys = ('id', 'name', 'version', 'author', 'license', 'icon', 'description', 'plugin_api', 'tags', 'dependencies')
pathlib.Path(sys.argv[2]).write_text('[[plugin]]\n' + ''.join(
    f'{key} = {json.dumps(manifest[key])}\n' for key in keys))
PY
fi
printf '%s\n' "$destination"
