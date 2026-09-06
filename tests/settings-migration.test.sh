#!/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
sandbox=$(mktemp -d /tmp/syncshell-settings-test.XXXXXX)
trap 'find "$sandbox" -depth -delete' EXIT
helper=$root/hosts/omarchy/scripts/syncthing-settings.sh
template=$root/hosts/omarchy/config/settings.toml
mkdir -p "$sandbox/bin/x86_64" "$sandbox/hosts/omarchy" \
  "$sandbox/config/omarchy/ilyazar.syncthing" "$sandbox/state" "$sandbox/runtime"
cp -a "$root/shared" "$sandbox/shared"
cp -a "$root/hosts/omarchy/." "$sandbox/hosts/omarchy/"
ln -s /usr/share/omarchy/shell/Commons "$sandbox/Commons"
ln -s /usr/share/omarchy/shell/Ui "$sandbox/Ui"
cp "$root/tests-settings-migration.qml" "$sandbox/"
export TEST_SANDBOX=$sandbox TEST_REFERENCE=$sandbox/reference.toml
export XDG_CONFIG_HOME=$sandbox/config XDG_STATE_HOME=$sandbox/state
export XDG_RUNTIME_DIR=$sandbox/runtime
export PATH=$sandbox/bin:$PATH

cat >"$sandbox/bin/omarchy" <<'MOCK'
#!/bin/bash
set -euo pipefail
[[ $1 == launch && $2 == editor && $# == 4 ]]
printf '%s\n' "$3" "$4" >"$TEST_SANDBOX/editor-args"
ln -s "$4" "$TEST_REFERENCE"
MOCK
cat >"$sandbox/bin/x86_64/syncshell-core" <<'MOCK'
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
chmod 755 "$sandbox/bin/omarchy" "$sandbox/bin/x86_64/syncshell-core"
sed -e 's/version = 2/version = 1/' -e 's/"branded"/"themed"/' \
  -e 's/"omarchy"/"default"/' -e 's/"enabled"/"disabled"/' \
  -e 's/seconds = 15/seconds = 27/' "$template" >"$sandbox/original.toml"
cp "$sandbox/original.toml" "$sandbox/owner.toml"
chmod 640 "$sandbox/owner.toml"
target=$sandbox/config/omarchy/ilyazar.syncthing/settings.toml
ln -s "$sandbox/owner.toml" "$target"
QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
  timeout 12s quickshell --no-color -p "$sandbox/tests-settings-migration.qml"
[[ -L $target && $(stat -c %a "$sandbox/owner.toml") == 640 ]]
cmp "$sandbox/original.toml" "$sandbox"/owner.toml.before-port.*
[[ $(head -n 1 "$sandbox/editor-args") == "$target" ]]
[[ -f $(tail -n 1 "$sandbox/editor-args") ]]
# Cold startup and migration may configure intent, but never mutate the daemon.
jq -es 'all(.type == "configure" or .type == "shutdown")' \
  "$sandbox/requests" >/dev/null

# A stale preview cannot replace an intervening user edit.
jq -n --rawfile original "$sandbox/original.toml" \
  --rawfile replacement "$template" '{original:$original,replacement:$replacement}' \
  | jq -c . >"$sandbox/request.json"
cp "$target" "$sandbox/before.toml"
if bash "$helper" migrate "$target" <"$sandbox/request.json" \
    >"$sandbox/output" 2>"$sandbox/error"; then
  printf 'stale preview was accepted\n' >&2
  exit 1
fi
cmp "$sandbox/before.toml" "$target"
grep -q 'changed since the preview' "$sandbox/error"
[[ $(find "$sandbox" -name '*.before-port.*' | wc -l) == 1 ]]
# Ordinary preference writes also retain managed symlinks.
bash "$helper" set-service-state "$template" "$target" themed enabled >/dev/null
[[ -L $target && $(stat -c %a "$sandbox/owner.toml") == 640 ]]
grep -q '^service_state = "enabled"$' "$target"
printf 'settings writer tests passed\n'
