#!/bin/bash
set -euo pipefail

integration_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$integration_root/../.." && pwd)
target=${1:-}

[[ -n $target && $target == /* ]] || {
  printf 'usage: %s EMPTY_ABSOLUTE_DIRECTORY\n' "$0" >&2
  exit 2
}
mkdir -p -- "$target"
[[ -z $(find "$target" -mindepth 1 -maxdepth 1 -print -quit) ]] || {
  printf 'Waybar target must be empty\n' >&2
  exit 1
}

install -d -- "$target/shared" "$target/bin/x86_64"
install -m 0644 -- "$integration_root/manifest.json" \
  "$integration_root/shell.qml" "$integration_root/style.css" "$target/"
install -m 0755 -- "$integration_root/install.sh" \
  "$integration_root/remove.sh" "$integration_root/status.sh" \
  "$integration_root/waybar-config.py" "$target/"
install -m 0644 -- "$repo_root/shared/CoreProcess.qml" \
  "$repo_root/shared/AdapterService.qml" \
  "$repo_root/shared/DeviceWorkflow.qml" "$target/shared/"
install -m 0755 -- "$repo_root/bin/x86_64/syncshell-core" \
  "$target/bin/x86_64/syncshell-core"
(cd -- "$repo_root" && \
  sha256sum --check packaging/bundled/SHA256SUMS >/dev/null)
(cd -- "$target" && sha256sum bin/x86_64/syncshell-core) \
  >"$target/SHA256SUMS"
printf '[ok] assembled Waybar adapter\n'
