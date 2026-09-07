#!/bin/bash
set -euo pipefail

# shellcheck source=qml-test-helper.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/qml-test-helper.sh"
test_home="$test_root/home"

stage_omarchy_test rescan-core-loss shared hosts/omarchy bin/x86_64/syncshell-core
mkdir -p -- "$test_home/.config" "$test_home/.local/state/syncthing"
config="$test_home/.local/state/syncthing/config.xml"
printf '%s\n' \
  '<configuration>' \
  '  <gui tls="false">' \
  '    <address>127.0.0.1:1</address>' \
  '    <apikey>test-placeholder</apikey>' \
  '  </gui>' \
  '</configuration>' >"$config"
chmod 600 -- "$config"

HOME="$test_home" \
XDG_CONFIG_HOME="$test_home/.config" \
XDG_STATE_HOME="$test_home/.local/state" \
  timeout 15s quickshell --no-color -p "$test_root/shell.qml"

if pgrep -f "$test_root/bin/x86_64/syncshell-core" >/dev/null; then
  printf '%s\n' 'rescan core-loss test orphaned a native core' >&2
  exit 1
fi
