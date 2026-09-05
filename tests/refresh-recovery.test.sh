#!/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d /tmp/syncshell-refresh-recovery.XXXXXX)
trap 'find "$test_root" -depth -delete' EXIT

mkdir -p -- "$test_root/bin/x86_64" "$test_root/hosts/omarchy" \
  "$test_root/config/omarchy/ilyazar.syncthing" "$test_root/state"
cp -a -- "$root/shared" "$test_root/shared"
cp -a -- "$root/hosts/omarchy/." "$test_root/hosts/omarchy/"
ln -s -- /usr/share/omarchy/shell/Commons "$test_root/Commons"
ln -s -- /usr/share/omarchy/shell/Ui "$test_root/Ui"
cp -- "$root/tests-refresh-recovery.qml" "$test_root/"
cp -- "$root/tests/refresh-recovery-core-mock.sh" \
  "$test_root/bin/x86_64/syncshell-core"
chmod 755 -- "$test_root/bin/x86_64/syncshell-core"
sed 's/web_ui_theme = "omarchy"/web_ui_theme = "default"/' \
  "$root/hosts/omarchy/config/settings.toml" \
  >"$test_root/config/omarchy/ilyazar.syncthing/settings.toml"

XDG_CONFIG_HOME="$test_root/config" XDG_STATE_HOME="$test_root/state" \
QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
  timeout 10s quickshell --no-color -p "$test_root/tests-refresh-recovery.qml"
