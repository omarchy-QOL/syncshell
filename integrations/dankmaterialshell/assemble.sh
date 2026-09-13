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
  printf 'DankMaterialShell target must be empty\n' >&2
  exit 1
}

install -d -- "$target/shared" "$target/bin/x86_64"
install -m 0644 -- "$integration_root/plugin.json" \
  "$integration_root/SyncshellDaemon.qml" \
  "$integration_root/SyncshellWidget.qml" "$target/"
install -m 0644 -- "$repo_root/shared/CoreProcess.qml" \
  "$repo_root/shared/AdapterService.qml" "$target/shared/"
install -m 0755 -- "$repo_root/bin/x86_64/syncshell-core" \
  "$target/bin/x86_64/syncshell-core"
"$repo_root/packaging/bundled/verify.sh" >/dev/null
printf '[ok] assembled DMS adapter\n'
