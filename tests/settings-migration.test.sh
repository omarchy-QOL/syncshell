#!/bin/bash
set -euo pipefail

# shellcheck source=qml-test-helper.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/qml-test-helper.sh"
helper=$root/hosts/omarchy/scripts/syncthing-settings.sh
template=$root/hosts/omarchy/config/settings.toml
stage_omarchy_test settings-migration shared hosts/omarchy
mkdir -p -- "$test_root/config/omarchy/ilyazar.syncthing" "$test_root/state" "$test_root/runtime"
export TEST_SANDBOX=$test_root TEST_REFERENCE=$test_root/reference.toml
export XDG_CONFIG_HOME=$test_root/config XDG_STATE_HOME=$test_root/state
export XDG_RUNTIME_DIR=$test_root/runtime
export PATH=$test_root/bin:$PATH

cat >"$test_root/bin/omarchy" <<'MOCK'
#!/bin/bash
set -euo pipefail
[[ $1 == launch && $2 == editor && $# == 4 ]]
printf '%s\n' "$3" "$4" >"$TEST_SANDBOX/editor-args"
ln -s "$4" "$TEST_REFERENCE"
MOCK
cat >"$test_root/bin/x86_64/syncshell-core" <<'MOCK'
#!/bin/bash
set -euo pipefail
printf '%s\n' \
  '{"v":1,"type":"hello","build":{"version":"test","protocol":1}}' \
  '{"v":1,"type":"snapshot","revision":1,"state":{"connection":{"phase":"ready","online":true,"fresh":true},"webUi":{"theme":"default","guiAssets":"/tmp/test-gui"},"folders":[],"counts":{}}}'
while IFS= read -r line; do
  printf '%s\n' "$line" >>"$TEST_SANDBOX/requests"
  id=$(jq -er '.id' <<<"$line")
  printf '{"v":1,"type":"result","id":"%s","ok":true,"revision":1}\n' "$id"
done
MOCK
chmod 755 "$test_root/bin/omarchy" "$test_root/bin/x86_64/syncshell-core"
sed -e 's/version = 2/version = 1/' -e 's/"branded"/"themed"/' \
  -e 's/"omarchy"/"default"/' -e 's/"enabled"/"disabled"/' \
  -e 's/seconds = 15/seconds = 27/' "$template" >"$test_root/original.toml"
cp "$test_root/original.toml" "$test_root/owner.toml"
chmod 640 "$test_root/owner.toml"
target=$test_root/config/omarchy/ilyazar.syncthing/settings.toml
ln -s "$test_root/owner.toml" "$target"
QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
  timeout 12s quickshell --no-color -p "$test_root/shell.qml"
[[ -L $target && $(stat -c %a "$test_root/owner.toml") == 640 ]]
cmp "$test_root/original.toml" "$test_root"/owner.toml.before-port.*
[[ $(head -n 1 "$test_root/editor-args") == "$target" ]]
[[ -f $(tail -n 1 "$test_root/editor-args") ]]
# Cold startup and migration may configure intent, but never mutate the daemon.
jq -es 'all(.type == "configure" or .type == "shutdown")' \
  "$test_root/requests" >/dev/null

# A stale preview cannot replace an intervening user edit.
jq -n --rawfile original "$test_root/original.toml" \
  --rawfile replacement "$template" '{original:$original,replacement:$replacement}' \
  | jq -c . >"$test_root/request.json"
cp "$target" "$test_root/before.toml"
if bash "$helper" migrate "$target" <"$test_root/request.json" \
    >"$test_root/output" 2>"$test_root/error"; then
  printf 'stale preview was accepted\n' >&2
  exit 1
fi
cmp "$test_root/before.toml" "$target"
grep -q 'changed since the preview' "$test_root/error"
[[ $(find "$test_root" -name '*.before-port.*' | wc -l) == 1 ]]
# Ordinary preference writes also retain managed symlinks.
bash "$helper" set-service-state "$template" "$target" themed enabled >/dev/null
[[ -L $target && $(stat -c %a "$test_root/owner.toml") == 640 ]]
grep -q '^service_state = "enabled"$' "$target"
printf 'settings writer tests passed\n'
