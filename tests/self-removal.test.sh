#!/bin/bash
set -euo pipefail

# shellcheck source=qml-test-helper.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/qml-test-helper.sh"
stage_omarchy_test self-removal shared hosts/omarchy
mkdir -p -- "$test_root/home" "$test_root/config" "$test_root/state" "$test_root/runtime"
export HOME=$test_root/home XDG_CONFIG_HOME=$test_root/config
export XDG_STATE_HOME=$test_root/state XDG_RUNTIME_DIR=$test_root/runtime
export TEST_SANDBOX=$test_root
cp "$root/tests/core-process-mock.sh" "$test_root/bin/x86_64/syncshell-core"
chmod 755 "$test_root/bin/x86_64/syncshell-core"

# Only the staged helper can run; no native plugin removal is performed.
cat >"$test_root/hosts/omarchy/scripts/syncthing-remove.sh" <<'MOCK'
#!/bin/bash
set -euo pipefail
[[ $# == 4 && $1 == start ]]
printf '%s\n' "$3|$4" >>"$TEST_SANDBOX/removals"
MOCK
QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
  timeout 15s quickshell --no-color -p "$test_root/shell.qml"
[[ $(wc -l <"$test_root/removals") == 4 ]]
[[ $(sed -n '1p' "$test_root/removals") == '|preserve' ]]
[[ $(sed -n '2p' "$test_root/removals") == '|purge' ]]
[[ $(sed -n '3p' "$test_root/removals") == '/test/gui|preserve' ]]
[[ $(sed -n '4p' "$test_root/removals") == '/test/gui|purge' ]]
printf 'self removal tests passed\n'
