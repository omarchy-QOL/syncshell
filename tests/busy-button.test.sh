#!/bin/bash
set -euo pipefail

# shellcheck source=qml-test-helper.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/qml-test-helper.sh"

configure_visual_test "$@"
stage_omarchy_test busy-button \
  hosts/omarchy/ui/BusyButton.qml \
  hosts/omarchy/ui/SyncshellToolTip.qml \
  hosts/omarchy/ui/UiConstants.js \
  tests/VisualPause.qml

timeout "$visual_test_timeout" quickshell --no-color -p "$test_root/shell.qml"
