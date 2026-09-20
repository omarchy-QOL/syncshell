#!/bin/bash
set -euo pipefail

source_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
install_root="$HOME/.local/share/syncshell/waybar"
waybar_root="$HOME/.config/waybar"
if [[ -e $waybar_root/config.jsonc || ! -e $waybar_root/config ]]; then
  config_file="$waybar_root/config.jsonc"
else
  config_file="$waybar_root/config"
fi
style_file="$waybar_root/style.css"
service_root="$HOME/.config/systemd/user"

(cd -- "$source_root" && sha256sum --check SHA256SUMS >/dev/null)
install -d -- "$install_root/shared" "$install_root/bin/x86_64" \
  "$waybar_root" "$service_root"
install -m 0644 -- "$source_root/manifest.json" "$source_root/shell.qml" \
  "$install_root/"
install -m 0644 -- "$source_root/shared/CoreProcess.qml" \
  "$source_root/shared/AdapterService.qml" \
  "$source_root/shared/DeviceWorkflow.qml" \
  "$source_root/shared/RescanTracker.qml" "$install_root/shared/"
install -m 0755 -- "$source_root/bin/x86_64/syncshell-core" \
  "$install_root/bin/x86_64/syncshell-core"
install -m 0755 -- "$source_root/status.sh" \
  "$source_root/waybar-config.py" "$source_root/remove.sh" "$install_root/"
install -m 0644 -- "$source_root/style.css" "$waybar_root/syncshell.css"

if [[ -e $config_file && ! -e $config_file.syncshell-before ]]; then
  cp -a -- "$config_file" "$config_file.syncshell-before"
fi

"$install_root/waybar-config.py" install --config "$config_file" \
  --style "$style_file" --root "$install_root"

temporary=$(mktemp --tmpdir="$service_root" .syncshell-waybar.XXXXXX)
trap 'rm -f -- "$temporary"' EXIT
{
  printf '%s\n' '[Unit]'
  printf '%s\n' 'Description=Syncshell Waybar bridge'
  printf '%s\n' 'After=graphical-session.target syncthing.service'
  printf '\n%s\n' '[Service]'
  printf 'ExecStart=/usr/bin/quickshell -p %s\n' "$install_root"
  printf '%s\n' 'Restart=on-failure'
  printf '%s\n' 'RestartSec=2'
  printf '\n%s\n' '[Install]'
  printf '%s\n' 'WantedBy=default.target'
} >"$temporary"
chmod 0644 -- "$temporary"
mv -- "$temporary" "$service_root/syncshell-waybar.service"
trap - EXIT

systemctl --user daemon-reload
systemctl --user enable --now syncshell-waybar.service
pkill -SIGUSR2 -x waybar 2>/dev/null || true
printf '[ok] installed Syncshell Waybar adapter\n'
