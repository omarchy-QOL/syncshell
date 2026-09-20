#!/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT

bash "$root/integrations/dankmaterialshell/assemble.sh" "$work/Syncshell"
jq -e --arg version "$(jq -er .version "$root/manifest.json")" \
  '.version == $version and .requires_dms == ">=1.5.3"' \
  "$work/Syncshell/plugin.json" >/dev/null
test -x "$work/Syncshell/bin/x86_64/syncshell-core"
test -f "$work/Syncshell/shared/AdapterService.qml"
test -f "$work/Syncshell/shared/DeviceWorkflow.qml"
test -f "$work/Syncshell/shared/RescanTracker.qml"
printf '[ok] DMS adapter bundle contract passed\n'
