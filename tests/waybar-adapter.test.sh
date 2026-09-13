#!/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT

bash "$root/integrations/waybar/assemble.sh" "$work/bundle"
test -x "$work/bundle/bin/x86_64/syncshell-core"
test -x "$work/bundle/status.sh"
(cd -- "$work/bundle" && sha256sum --check SHA256SUMS >/dev/null)
rg -q 'AdapterService' "$work/bundle/shell.qml"
rg -q 'IpcHandler' "$work/bundle/shell.qml"
rg -q 'HyprlandFocusGrab' "$work/bundle/shell.qml"
rg -q 'pendingForgetId' "$work/bundle/shell.qml"
rg -q 'root.moreOpen.*"Less".*"More"' "$work/bundle/shell.qml"

mkdir -p -- "$work/waybar"
config="$work/waybar/config.jsonc"
style="$work/waybar/style.css"
printf '%s\n' '{' '  // unrelated setting' \
  '  "modules-left": ["clock"],' \
  '  "modules-right": ["tray"],' \
  '  "clock": {"format": "{:%H:%M}"}' '}' >"$config"
printf '%s\n' '#clock { color: white; }' >"$style"

for _ in 1 2; do
  "$work/bundle/waybar-config.py" install --config "$config" \
    --style "$style" --root "$work/bundle"
done
[[ $(rg -c 'syncshell module start' "$config") == 1 ]]
[[ $(rg -c 'syncshell placement start' "$config") == 1 ]]
[[ $(rg -c 'syncshell style start' "$style") == 1 ]]
rg -q 'unrelated setting' "$config"
rg -q '"tray"' "$config"
rg -q '#clock' "$style"

"$work/bundle/waybar-config.py" remove --config "$config" \
  --style "$style" --root "$work/bundle"
if rg -q syncshell "$config" "$style"; then
  printf 'Waybar removal left managed configuration\n' >&2
  exit 1
fi
rg -q 'unrelated setting' "$config"
rg -q '"tray"' "$config"
rg -q '#clock' "$style"

if rg -n 'SyncthingController|syncthing-api\.sh|curl' "$work/bundle"; then
  printf 'Waybar adapter retained the deleted QML engine\n' >&2
  exit 1
fi
printf '[ok] Waybar adapter contract passed\n'
