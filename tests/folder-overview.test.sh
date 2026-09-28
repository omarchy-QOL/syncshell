#!/bin/bash
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/qml-test-helper.sh"
stage_omarchy_test folder-overview hosts/omarchy shared assets
timeout 10s quickshell --no-color -p "$test_root/shell.qml"
