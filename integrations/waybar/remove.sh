#!/bin/bash
set -euo pipefail

install_root="$HOME/.local/share/syncshell/waybar"
waybar_root="$HOME/.config/waybar"
style_file="$waybar_root/style.css"
service_file="$HOME/.config/systemd/user/syncshell-waybar.service"

if [[ -x $install_root/waybar-config.py ]]; then
  for config_file in "$waybar_root/config.jsonc" "$waybar_root/config"; do
    "$install_root/waybar-config.py" remove --config "$config_file" \
      --style "$style_file" --root "$install_root"
  done
fi
systemctl --user disable --now syncshell-waybar.service 2>/dev/null || true
[[ ! -e $service_file ]] || unlink "$service_file"
systemctl --user daemon-reload
pkill -SIGUSR2 -x waybar 2>/dev/null || true

for path in \
    "$install_root/bin/x86_64/syncshell-core" \
    "$install_root/shared/CoreProcess.qml" \
    "$install_root/shared/AdapterService.qml" \
    "$install_root/shared/DeviceWorkflow.qml" \
    "$install_root/shared/RescanTracker.qml" \
    "$install_root/manifest.json" \
    "$install_root/shell.qml" \
    "$install_root/status.sh" \
    "$install_root/waybar-config.py" \
    "$install_root/remove.sh" \
    "$install_root/position" \
    "$waybar_root/syncshell.css"; do
  [[ ! -e $path ]] || unlink "$path"
done
rmdir "$install_root/bin/x86_64" "$install_root/bin" \
  "$install_root/shared" "$install_root" 2>/dev/null || true
printf '[ok] removed Syncshell Waybar adapter and kept Syncthing data\n'
