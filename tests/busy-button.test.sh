#!/bin/bash
set -euo pipefail

# shellcheck source=qml-test-helper.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/qml-test-helper.sh"

stage_omarchy_test busy-button hosts/omarchy/ui/BusyButton.qml

timeout 10s quickshell --no-color -p "$test_root/shell.qml"
