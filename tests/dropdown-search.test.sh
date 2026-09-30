#!/bin/bash
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/qml-test-helper.sh"
configure_visual_test "$@"
stage_omarchy_test dropdown-search hosts/omarchy/ui hosts/omarchy/models \
  tests/VisualPause.qml
timeout "$visual_test_timeout" quickshell --no-color -p "$test_root/shell.qml"
