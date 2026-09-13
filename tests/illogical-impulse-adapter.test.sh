#!/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
manifest="$root/integrations/illogical-impulse/manifest.json"
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
commit=$(jq -er .commit "$manifest")
git -C "$work" init -q ii
git -C "$work/ii" remote add origin "$(jq -er .repository "$manifest")"
git -C "$work/ii" fetch -q --depth=1 origin "$commit"
git -C "$work/ii" checkout -q --detach FETCH_HEAD
bash "$root/integrations/illogical-impulse/apply.sh" "$work/ii"
config="$work/ii/dots/.config/quickshell/ii"
git -C "$work/ii" diff --check
test -x "$config/syncshell/bin/x86_64/syncshell-core"
rg -q 'SyncshellIndicator' "$config/modules/ii/bar/BarContent.qml"
rg -q 'WlrKeyboardFocus.OnDemand' "$config/modules/ii/bar/SyncshellPopup.qml"
rg -q 'HyprlandFocusGrab' \
  "$config/modules/ii/bar/SyncshellPopup.qml"
rg -q 'Keys.onEscapePressed:' \
  "$config/modules/ii/bar/SyncshellPopup.qml"
rg -q 'pendingForgetId' "$config/modules/ii/bar/SyncshellPopup.qml"
rg -q 'root.moreOpen.*Translation.tr\("Less"\)' \
  "$config/modules/ii/bar/SyncshellPopup.qml"
rg -q 'Flickable' "$config/modules/ii/bar/SyncshellPopup.qml"
if rg -n 'SyncthingController|syncthing-api\.sh|curl' "$config/syncshell" \
    "$config/services/Syncshell.qml"; then
  printf 'Illogical Impulse retained the deleted QML engine\n' >&2
  exit 1
fi
printf '[ok] Illogical Impulse adapter contract passed\n'
