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
grep -Fq 'dms|ii|caelestia|waybar' "$root/install.sh" \
  || fail "cross-shell installer omits a supported adapter"

jq -e '.version == "0.1.8"' "$root/manifest.json" >/dev/null \
  || fail "manifest is not the 0.1.8 candidate"
[[ -f $root/packaging/bundled/SHA256SUMS ]] \
  || fail "canonical bundled checksum list is missing"
[[ $(find "$root/packaging/bundled" -maxdepth 1 -type f \
  \( -iname '*sha256*' -o -name SHA256SUMS \) | wc -l) -eq 1 ]] \
  || fail "bundled artifact has duplicate checksum lists"

if git -C "$root" ls-files --stage | grep -q '^120000 '; then
  fail "plugin tree contains a symbolic link"
fi
[[ ! -f $root/.gitmodules ]] || fail "plugin tree contains submodules"

adapter_hosts=(
  caelestia
  dankmaterialshell
  illogical-impulse
  waybar
)
for host in "${adapter_hosts[@]}"; do
  host_dir="$root/hosts/$host"
  [[ -d $host_dir ]] || fail "adapter host directory is missing: $host"
  mapfile -t entries < <(
    find "$host_dir" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort
  )
  [[ ${#entries[@]} -eq 1 && ${entries[0]} == README.md ]] \
    || fail "adapter host must contain only README.md: $host"
  grep -Fq 'Syncshell supports' "$host_dir/README.md" \
    || fail "adapter host README omits its support claim: $host"
done

if git -C "$root" ls-files \
    | grep -Eq '(^|/)(TODO|sources|\.research)(/|$)'; then
  fail "implementation prompts or transcripts are tracked"
fi

if rg -n '/home/iz|/home-hdd-cold|chatgpt-share' \
    "$root/docs" "$root/hosts" >/dev/null; then
  fail "tracked architecture material contains developer-local evidence"
fi

grep -Fq 'Omarchy remains the sole owner' \
  "$root/docs/adr/0003-omarchy-settings-boundary.md" \
  || fail "Omarchy settings ownership is missing"
grep -Fq 'Unit presence or activity is not authority' \
  "$root/docs/ownership.md" \
  || fail "lifecycle authority rule is missing"
grep -Fq 'There is no mixed runtime, fallback, alias, or feature flag' \
  "$root/docs/ownership.md" \
  || fail "one-way cutover rule is missing"

printf '%s[ok]%s architecture contract passed\n' "$green" "$reset"
