#!/bin/bash
set -euo pipefail

readonly expected_commit=42d0aae17b744a38cd05c9044c189bfc9b13869a
integration_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$integration_root/../.." && pwd)
target=${1:-}
config_root="$target/dots/.config/quickshell/ii"

[[ -n $target && -d $target/.git ]] || {
  printf 'usage: %s ILLOGICAL_IMPULSE_CHECKOUT\n' "$0" >&2
  exit 2
}
[[ $(git -C "$target" rev-parse HEAD) == "$expected_commit" ]] \
  || { printf 'Illogical Impulse checkout has the wrong commit\n' >&2; exit 1; }
[[ -z $(git -C "$target" status --porcelain) ]] \
  || { printf 'Illogical Impulse checkout must be clean\n' >&2; exit 1; }

patch --dry-run --silent -d "$target" -p1 <"$integration_root/overlay.patch"
patch --silent -d "$target" -p1 <"$integration_root/overlay.patch"
install -d -- "$config_root/syncshell/shared" \
  "$config_root/syncshell/bin/x86_64"
install -m 0644 -- "$repo_root/shared/CoreProcess.qml" \
  "$repo_root/shared/AdapterService.qml" "$config_root/syncshell/shared/"
install -m 0755 -- "$repo_root/bin/x86_64/syncshell-core" \
  "$config_root/syncshell/bin/x86_64/syncshell-core"
install -m 0644 -- "$integration_root/files/SyncshellService.qml.in" \
  "$config_root/services/Syncshell.qml"
install -m 0644 -- "$integration_root/files/SyncshellIndicator.qml.in" \
  "$config_root/modules/ii/bar/SyncshellIndicator.qml"
install -m 0644 -- "$integration_root/files/SyncshellPopup.qml.in" \
  "$config_root/modules/ii/bar/SyncshellPopup.qml"
(cd -- "$repo_root" && \
  sha256sum --check packaging/bundled/SHA256SUMS >/dev/null)
printf '[ok] applied Illogical Impulse adapter\n'
