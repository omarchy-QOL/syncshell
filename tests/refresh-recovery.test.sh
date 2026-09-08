#!/bin/bash
set -euo pipefail

# shellcheck source=qml-test-helper.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/qml-test-helper.sh"

stage_omarchy_test refresh-recovery shared hosts/omarchy
mkdir -p -- "$test_root/config/omarchy/ilyazar.syncthing" "$test_root/state"
cp -- "$root/tests/refresh-recovery-core-mock.sh" \
  "$test_root/bin/x86_64/syncshell-core"
chmod 755 -- "$test_root/bin/x86_64/syncshell-core"
sed 's/web_ui_theme = "omarchy"/web_ui_theme = "default"/' \
  "$root/hosts/omarchy/config/settings.toml" \
  >"$test_root/config/omarchy/ilyazar.syncthing/settings.toml"

XDG_CONFIG_HOME="$test_root/config" XDG_STATE_HOME="$test_root/state" \
QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
  timeout 10s quickshell --no-color -p "$test_root/shell.qml"
