#!/usr/bin/env python3
import atexit
import json
import os
from pathlib import Path
import signal
import sys
import time

log = Path(os.environ['SYNCSHELL_WORKER_LOG'])

def event(kind):
    with log.open('a') as file:
        file.write(json.dumps({'event': kind, 'pid': os.getpid(), 'time': time.time()}) + '\n')

def send(value):
    print(json.dumps(dict(v=2, **value)), flush=True)

def terminate(*args):
    sys.exit(0)

signal.signal(signal.SIGTERM, terminate)
atexit.register(lambda: event('stopped'))
event('started')
send({'type': 'hello', 'build': {'version': 'owner-fixture'}})
send({'type': 'snapshot', 'revision': 1, 'state': {'connection': {'online': True, 'fresh': True},
    'identity': {'deviceId': 'local'}, 'folders': [], 'devices': []}})
for line in sys.stdin:
    request = json.loads(line)
    if request.get("action") == "folder.add-existing":
        time.sleep(.7)
    data = {'folderId': 'generated'} if request.get('action') == 'folder.suggest-id' else {}
    send({'type': 'result', 'id': request['id'], 'ok': True, 'data': data})
    if request['type'] == 'shutdown':
        send({'type': 'end', 'reason': 'shutdown'})
        break
