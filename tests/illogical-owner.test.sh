#!/bin/bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_root=${1:?usage: illogical-owner.test.sh PINNED_II_SHELL_ROOT}
work=$(mktemp -d /tmp/syncshell-ii-owner.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
bash "$root/integrations/illogical-impulse/assemble.sh"
python3 "$root/tests/illogical/prepare_sdk.py" "$source_root" "$work" --owner
if ! env -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
    QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= QT_STYLE_OVERRIDE=Fusion \
    QT_QUICK_BACKEND=software XDG_CONFIG_HOME="$work/config" \
    XDG_STATE_HOME="$work/state" XDG_CACHE_HOME="$work/cache" \
    SYNCSHELL_WORKER_LOG="$work/workers.jsonl" \
    timeout 20s quickshell --no-color -p "$work/qs/shell.qml" >"$work/log" 2>&1; then
  cat "$work/log"
  cat "$work/workers.jsonl" 2>/dev/null || true
  exit 1
fi
cat "$work/log"
! rg '(ERROR|WARN|\[fail\])' "$work/log"
rg -q '\[ok\] one owner' "$work/log"
python3 - "$work/workers.jsonl" <<'PY'
import json,os,sys,time
from pathlib import Path
path=Path(sys.argv[1])
# Each worker records which earlier workers were still alive when it started.
# Child signal handling can finish just after the QML engine exits.
for _ in range(50):
    events=[json.loads(line) for line in path.read_text().splitlines()]
    starts=[event for event in events if event['event']=='started']
    for event in starts:
        assert not event['alive'], f'overlapping worker ownership: {events}'
    live=set()
    for event in starts:
        try: os.kill(event['pid'],0)
        except ProcessLookupError: continue
        live.add(event['pid'])
    if not live: break
    time.sleep(.02)
assert len(starts)==3, events
assert not live, events
for pid in {event['pid'] for event in events}:
    try: os.kill(pid,0)
    except ProcessLookupError: continue
    raise AssertionError(f'worker still exists: {pid}')
print('[ok] all three real child processes exited without overlapping ownership')
PY
