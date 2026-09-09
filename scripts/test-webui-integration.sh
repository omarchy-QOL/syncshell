#!/bin/bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
runtime=$(mktemp -d -- "${TMPDIR:-/tmp}/syncshell-import-test.XXXXXX")
fixture_pid=''
cleanup() {
  if [[ -n $fixture_pid ]]; then
    kill -TERM "$fixture_pid" 2>/dev/null || true
    wait "$fixture_pid" || true
  fi
  rm -rf -- "$runtime"
}
trap cleanup EXIT
cd -- "$root"
python3 -m unittest discover -s tests -p import_webui_test.py
bash tests/scripts.test.sh --webui-only
go -C tests/integration build -o "$runtime/fixture" .
go -C core build -o "$runtime/syncshell-core" ./cmd/syncshell-core
mkdir "$runtime/bin"
export SYNCSHELL_TEST_PALETTE="$runtime/palette.tsv"
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/bash' 'cat -- "$SYNCSHELL_TEST_PALETTE"' >"$runtime/bin/omarchy-theme-color"
chmod 700 "$runtime/bin/omarchy-theme-color"
export PATH="$runtime/bin:$PATH"
printf '%s\t%s\n' background '#120f18' foreground '#e8dff2' accent '#ff7ab2' \
  muted '#666666' selection '#334455' lighter_background '#201d28' \
  darker_background '#100d18' dark_foreground '#111111' light_foreground '#eeeeee' \
  red '#ff5370' yellow '#ffcb6b' green '#c3e88d' cyan '#89ddff' blue '#82aaff' \
  magenta '#c792ea' orange '#ff8800' >"$SYNCSHELL_TEST_PALETTE"
for style in modern omarchy; do
  assets=$(bash hosts/omarchy/scripts/syncthing-theme.sh prepare "$style" "$runtime/gui")
  "$runtime/fixture" -fixture-assets "$assets" -runtime "$runtime/$style" \
    -fixture-port "${SYNCSHELL_TEST_PORT:-18401}" >"$runtime/fixture.log" 2>&1 &
  fixture_pid=$!
  for _ in {1..300}; do
    [[ ! -f $runtime/$style/ready.json ]] || break
    kill -0 "$fixture_pid" || { cat "$runtime/fixture.log"; exit 1; }
    sleep 0.1
  done
  [[ -f $runtime/$style/ready.json ]] || { cat "$runtime/fixture.log"; exit 1; }
  export SYNCSHELL_WEBUI_URL="http://127.0.0.1:${SYNCSHELL_TEST_PORT:-18401}"
  export SYNCSHELL_TEST_RUNTIME="$runtime/$style/primary"
  export SYNCSHELL_TEST_STYLE="$style"
  node tests/webui/plugin-smoke.mjs
  if [[ $style == modern ]]; then
    SYNCSHELL_CORE="$runtime/syncshell-core" dbus-run-session -- node tests/webui/live-desktop.mjs
  fi
  kill -TERM "$fixture_pid"
  wait "$fixture_pid"
  fixture_pid=''
done
