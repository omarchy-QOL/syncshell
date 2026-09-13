#!/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT

bash "$root/integrations/dankmaterialshell/assemble.sh" "$work/Syncshell"
jq -e '.version == "0.1.8" and .requires_dms == ">=1.5.3"' \
  "$work/Syncshell/plugin.json" >/dev/null
test -x "$work/Syncshell/bin/x86_64/syncshell-core"
test -f "$work/Syncshell/shared/AdapterService.qml"
rg -q 'horizontalBarPill' "$work/Syncshell/SyncshellWidget.qml"
rg -q 'verticalBarPill' "$work/Syncshell/SyncshellWidget.qml"
rg -q 'folder.rescan-all' "$work/Syncshell/shared/AdapterService.qml"
if rg -n 'SyncthingController|syncthing-api\.sh|curl' "$work/Syncshell"; then
  printf 'DMS adapter retained the deleted QML engine\n' >&2
  exit 1
fi
printf '[ok] DMS adapter bundle contract passed\n'
