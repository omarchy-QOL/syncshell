#!/bin/bash
set -euo pipefail

# shellcheck source=qml-test-helper.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/qml-test-helper.sh"
test_home="$test_root/home"
marker="$test_root/installation-ready"

stage_omarchy_test install-recovery shared hosts/omarchy
mkdir -p -- "$test_home/.config" "$test_home/.local/state"
cp -- "$root/tests/install-recovery-core-mock.sh" \
  "$test_root/bin/x86_64/syncshell-core"
chmod 755 -- "$test_root/bin/x86_64/syncshell-core"

HOME="$test_home" \
XDG_CONFIG_HOME="$test_home/.config" \
XDG_STATE_HOME="$test_home/.local/state" \
SYNCSHELL_RECOVERY_MARKER="$marker" \
  timeout 15s quickshell --no-color -p "$test_root/shell.qml"

if pgrep -f "$test_root/bin/x86_64/syncshell-core" >/dev/null; then
  printf '%s\n' 'install recovery test orphaned a native core' >&2
  exit 1
fi
