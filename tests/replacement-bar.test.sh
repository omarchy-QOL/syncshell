#!/bin/bash
set -euo pipefail

# shellcheck source=qml-test-helper.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/qml-test-helper.sh"
stage_omarchy_test replacement-bar hosts/omarchy shared assets
mkdir -p -- "$test_root/home" "$test_root/config" "$test_root/state"
# The panel needs the desktop's Wayland session, so keep XDG_RUNTIME_DIR.
export HOME=$test_root/home XDG_CONFIG_HOME=$test_root/config XDG_STATE_HOME=$test_root/state
cp "$root/tests/core-process-mock.sh" "$test_root/bin/syncshell-core"
chmod 755 "$test_root/bin/syncshell-core"
timeout 15s quickshell --no-color -p "$test_root/shell.qml"
printf 'replacement bar tests passed\n'
