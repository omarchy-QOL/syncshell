#!/bin/bash
set -euo pipefail

# shellcheck source=qml-test-helper.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/qml-test-helper.sh"
stage_qml_test standalone shared hosts/standalone
quickshell --no-color -p "$test_root/shell.qml"
