#!/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
green=$'\033[0;32m'
red=$'\033[0;31m'
reset=$'\033[0m'

fail() {
  printf '%s[error]%s %s\n' "$red" "$reset" "$*" >&2
  exit 1
}

manifest_count=$(
  find "$root" -maxdepth 1 -type f -name manifest.json -print \
    | wc -l
)
[[ $manifest_count -eq 1 ]] || fail "expected one root manifest"

for entry_point in manifest.json Panel.qml Service.qml; do
  [[ -f $root/$entry_point && ! -L $root/$entry_point ]] \
    || fail "$entry_point must be a regular root entry point"
done
[[ -x $root/install.sh ]] || fail "cross-shell installer is missing"
jq -e '.version | type == "string" and length > 0' \
  "$root/manifest.json" >/dev/null || fail "manifest version is missing"
[[ -f $root/packaging/bundled/SHA256SUMS ]] \
  || fail "canonical bundled checksum list is missing"
[[ $(find "$root/packaging/bundled" -maxdepth 1 -type f \
  \( -iname '*sha256*' -o -name SHA256SUMS \) | wc -l) -eq 1 ]] \
  || fail "bundled artifact has duplicate checksum lists"

if git -C "$root" ls-files --stage | grep -q '^120000 '; then
  fail "plugin tree contains a symbolic link"
fi
[[ ! -f $root/.gitmodules ]] || fail "plugin tree contains submodules"

printf '%s[ok]%s package layout passed\n' "$green" "$reset"
