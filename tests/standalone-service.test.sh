#!/bin/bash
set -euo pipefail

# shellcheck source=qml-test-helper.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/qml-test-helper.sh"
stage_qml_test standalone-service shared hosts/standalone
cp -- "$root/tests/core-process-mock.sh" \
  "$test_root/bin/x86_64/syncshell-core"
chmod 755 -- "$test_root/bin/x86_64/syncshell-core"

SYNCSHELL_TEST_PLUGIN_ROOT="$test_root" \
  timeout 15s quickshell --no-color -p "$test_root/shell.qml"
if pgrep -f "$test_root/bin/x86_64/syncshell-core" >/dev/null; then
  printf '%s\n' 'standalone service fixture was orphaned' >&2
  exit 1
fi
printf '%s\n' 'standalone service tests passed'
