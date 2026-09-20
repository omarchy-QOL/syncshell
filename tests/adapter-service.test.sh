#!/bin/bash
# shellcheck disable=SC1091,SC2154
set -euo pipefail

# shellcheck source=qml-test-helper.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/qml-test-helper.sh"
stage_qml_test adapter-service shared
install -m 0755 -- "$root/tests/adapter-service-core-mock.sh" \
  "$test_root/bin/x86_64/syncshell-core"
SYNCSHELL_TEST_PLUGIN_ROOT="$test_root" \
  timeout 15s quickshell --no-color -p "$test_root/shell.qml" 2>&1 \
  | tee "$test_root/output.log"
grep -Fq 'adapter service tests passed' "$test_root/output.log"
printf '[ok] adapter service tests passed\n'
