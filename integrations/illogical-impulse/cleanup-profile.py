#!/usr/bin/env python3
"""Retry owned profile cleanup through the same Go authority as the native UI."""
import argparse
import json
import os
from pathlib import Path
import selectors
import subprocess
import sys
import time


def cleanup(bundle, config):
    command = [str(bundle / 'bin/syncshell-core'), 'stream', '--config', str(config),
               '--web-profile-authorized', '--web-profile-owner', 'illogical-impulse',
               '--web-profile-bundle', str(bundle / 'webui')]
    process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.DEVNULL, bufsize=0)
    poller = selectors.DefaultSelector()
    poller.register(process.stdout, selectors.EVENT_READ)
    deadline = time.monotonic() + 30
    sent = False
    buffer = b""
    messages = []
    try:
        while time.monotonic() < deadline:
            if not messages and not poller.select(0.5):
                if process.poll() is not None:
                    raise RuntimeError('Core exited before cleanup; check the selected configuration')
                continue
            if not messages:
                data = os.read(process.stdout.fileno(), 65536)
                if not data:
                    raise RuntimeError('Core closed the cleanup session')
                buffer += data
                lines = buffer.split(b'\n')
                buffer = lines.pop()
                messages.extend(json.loads(line) for line in lines if line)
                if not messages:
                    continue
            message = messages.pop(0)
            if message.get('v') != 2:
                raise RuntimeError('Incompatible core protocol')
            if message.get('type') == 'snapshot' and not sent:
                connection = message.get('state', {}).get('connection', {})
                if not connection.get('online'):
                    if connection.get('phase') not in ('loading', 'discovering'):
                        raise RuntimeError('Syncthing is unavailable; start or authorize the selected instance and retry')
                    continue
                process.stdin.write((json.dumps({'v': 2, 'type': 'action', 'id': 'cleanup',
                                                'action': 'webui.remove-profile', 'args': {}}) + '\n').encode())
                process.stdin.flush()
                sent = True
            if message.get('type') == 'result' and message.get('id') == 'cleanup':
                if not message.get('ok'):
                    raise RuntimeError(message.get('error', {}).get('message', 'Cleanup failed'))
                print('[ok] restored default UI and removed only Illogical Impulse profiles')
                return
        raise RuntimeError('Cleanup timed out; no service was started or stopped')
    finally:
        poller.close()
        if process.poll() is None:
            try:
                process.stdin.write(b'{"v":2,"type":"shutdown","id":"shutdown"}\n')
                process.stdin.flush()
                process.wait(timeout=3)
            except (BrokenPipeError, subprocess.TimeoutExpired):
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, required=True, help='Absolute path to the intended Syncthing config.xml')
    args = parser.parse_args()
    if not args.config.is_absolute() or not args.config.is_file():
        parser.error('--config must name an existing absolute config.xml path')
    try:
        cleanup(Path(__file__).resolve().parent, args.config)
    except (OSError, ValueError, RuntimeError) as error:
        print('syncshell: ' + str(error), file=sys.stderr)
        sys.exit(1)
