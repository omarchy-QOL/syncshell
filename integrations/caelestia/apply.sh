#!/bin/bash
set -euo pipefail

readonly expected_commit=1d0e5a588c61f1d905eba5fe8446ec222d37f50c
integration_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$integration_root/../.." && pwd)
target=${1:-}

[[ -n $target && -d $target/.git ]] || {
  printf 'usage: %s CAELESTIA_CHECKOUT\n' "$0" >&2
  exit 2
}
[[ $(git -C "$target" rev-parse HEAD) == "$expected_commit" ]] \
  || { printf 'Caelestia checkout has the wrong commit\n' >&2; exit 1; }
[[ -z $(git -C "$target" status --porcelain) ]] \
  || { printf 'Caelestia checkout must be clean\n' >&2; exit 1; }

patch --dry-run --silent -d "$target" -p1 <"$integration_root/overlay.patch"
patch --silent -d "$target" -p1 <"$integration_root/overlay.patch"
install -d -- "$target/syncshell/shared" "$target/syncshell/bin/x86_64"
install -m 0644 -- "$repo_root/shared/CoreProcess.qml" \
  "$repo_root/shared/AdapterService.qml" \
  "$repo_root/shared/DeviceWorkflow.qml" \
  "$repo_root/shared/RescanTracker.qml" "$target/syncshell/shared/"
install -m 0755 -- "$repo_root/bin/x86_64/syncshell-core" \
  "$target/syncshell/bin/x86_64/syncshell-core"
install -m 0644 -- "$integration_root/files/SyncshellService.qml.in" \
  "$target/services/Syncshell.qml"
install -m 0644 -- "$integration_root/files/SyncshellStatus.qml.in" \
  "$target/modules/bar/components/status/SyncshellStatus.qml"
install -m 0644 -- "$integration_root/files/SyncshellPopout.qml.in" \
  "$target/modules/bar/popouts/SyncshellPopout.qml"
(cd -- "$repo_root" && \
  sha256sum --check packaging/bundled/SHA256SUMS >/dev/null)
printf '[ok] applied Caelestia adapter\n'
