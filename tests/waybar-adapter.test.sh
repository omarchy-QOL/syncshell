#!/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT

bash "$root/integrations/waybar/assemble.sh" "$work/bundle"
test -x "$work/bundle/bin/syncshell-core"
test -x "$work/bundle/bin/x86_64/syncshell-core"
test -x "$work/bundle/bin/aarch64/syncshell-core"
test -x "$work/bundle/status.sh"
test ! -e "$work/bundle/waybar-config.py"
test -f "$work/bundle/shared/DeviceWorkflow.qml"
test -f "$work/bundle/shared/RescanTracker.qml"
(cd -- "$work/bundle" && sha256sum --check SHA256SUMS >/dev/null)
rg -q 'WantedBy=default.target' "$work/bundle/install.sh"
rg -Uq 'wants to connect"\n[[:space:]]+textFormat: Text\.PlainText' \
  "$work/bundle/shell.qml"
rg -Uq 'shortId\(root\.deviceFlow\.targetDeviceId\)\) \+ "\?"\n[[:space:]]+textFormat: Text\.PlainText' \
  "$work/bundle/shell.qml"

mkdir -p -- "$work/waybar"
config="$work/waybar/config.jsonc"
style="$work/waybar/style.css"
printf '%s\n' '{' '  // unrelated setting' \
  '  "position": "bottom",' \
  '  "modules-left": ["clock"],' \
  '  "modules-right": ["tray"],' \
  '  "clock": {"format": "{:%H:%M}"}' '}' >"$config"
printf '%s\n' '#clock { color: white; }' >"$style"

for _ in 1 2; do
  "$work/bundle/bin/syncshell-core" waybar-config install --config "$config" \
    --style "$style" --root "$work/bundle"
done
[[ $(rg -c 'syncshell module start' "$config") == 1 ]]
[[ $(rg -c 'syncshell placement start' "$config") == 1 ]]
[[ $(rg -c 'syncshell style start' "$style") == 1 ]]
rg -Uq 'syncshell placement end\n[[:space:]]*"tray"' "$config"
rg -q 'unrelated setting' "$config"
rg -q '"tray"' "$config"
rg -q '#clock' "$style"
[[ $(<"$work/bundle/position") == bottom ]]

empty_config="$work/waybar/empty.jsonc"
printf '%s\n' '{"modules-right": []}' >"$empty_config"
"$work/bundle/bin/syncshell-core" waybar-config install --config "$empty_config" \
  --style "$style" --root "$work/bundle"
if rg -Uq '"custom/syncshell",\n[[:space:]]*// syncshell placement end' \
    "$empty_config"; then
  printf 'Waybar empty module array retained a trailing comma\n' >&2
  exit 1
fi

"$work/bundle/bin/syncshell-core" waybar-config remove --config "$config" \
  --style "$style" --root "$work/bundle"
if rg -q syncshell "$config" "$style"; then
  printf 'Waybar removal left managed configuration\n' >&2
  exit 1
fi
rg -q 'unrelated setting' "$config"
rg -q '"tray"' "$config"
rg -q '#clock' "$style"

printf '[ok] Waybar adapter contract passed\n'
