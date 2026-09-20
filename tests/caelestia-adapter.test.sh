#!/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
manifest="$root/integrations/caelestia/manifest.json"
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
commit=$(jq -er .commit "$manifest")
git -C "$work" init -q caelestia
git -C "$work/caelestia" remote add origin "$(jq -er .repository "$manifest")"
git -C "$work/caelestia" fetch -q --depth=1 origin "$commit"
git -C "$work/caelestia" checkout -q --detach FETCH_HEAD
bash "$root/integrations/caelestia/apply.sh" "$work/caelestia"
git -C "$work/caelestia" diff --check
test -x "$work/caelestia/syncshell/bin/x86_64/syncshell-core"
test -f "$work/caelestia/syncshell/shared/DeviceWorkflow.qml"
test -f "$work/caelestia/syncshell/shared/RescanTracker.qml"
rg -q 'SyncshellStatus' \
  "$work/caelestia/modules/bar/components/StatusIcons.qml"
rg -q 'LIST_ENTRY\(syncshell, true\)' \
  "$work/caelestia/plugin/src/Caelestia/Config/barconfig.hpp"
rg -q 'DIRECTORY syncshell.*USE_SOURCE_PERMISSIONS' \
  "$work/caelestia/CMakeLists.txt"
printf '[ok] Caelestia adapter contract passed\n'
