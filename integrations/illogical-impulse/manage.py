#!/usr/bin/env python3
"""Install exact owned hooks and a checked payload with recoverable transactions."""
import argparse
import base64
import hashlib
import json
import os
import platform
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile

RECEIPT = '.syncshell-install.json'
TRANSACTION = '.syncshell-transaction'
HOOK_PATHS = {'shell.qml', 'modules/ii/bar/BarContent.qml',
              'modules/ii/verticalBar/VerticalBarContent.qml',
              'modules/waffle/bar/WaffleBarContent.qml'}


def fail(message):
    raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def plain(path):
    for entry in [path] + list(path.parents):
        if entry.is_symlink():
            fail(f'Refusing linked path: {entry}')


def atomic(path, data, mode=0o644):
    descriptor, temporary = tempfile.mkstemp(prefix='.syncshell-write-', dir=path.parent)
    try:
        with os.fdopen(descriptor, 'wb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def read_json(path):
    plain(path)
    return json.loads(path.read_text())


def verify_payload(payload, expected=None):
    plain(payload)
    recorded = expected if expected is not None else read_json(payload / 'SHA256SUMS.json')
    actual = {}
    for path in payload.rglob('*'):
        plain(path)
        if path.is_file() and path.relative_to(payload).as_posix() not in (RECEIPT, 'SHA256SUMS.json'):
            actual[str(path.relative_to(payload))] = digest(path.read_bytes())
    if actual != recorded:
        changed = sorted(set(actual) ^ set(recorded) | {p for p in actual.keys() & recorded.keys() if actual[p] != recorded[p]})
        fail('Payload checksum conflict: ' + ', '.join(changed[:8]))
    return recorded


def hook_text(hook):
    return '// syncshell begin ' + hook['id'] + '\n' + hook['text'] + '// syncshell end ' + hook['id'] + '\n'


def transform(data, hook, install):
    text = data.decode()
    block = hook_text(hook)
    if install:
        if 'syncshell begin ' + hook['id'] in text:
            fail('Partial or duplicate hook: ' + hook['id'])
        if text.count(hook['anchor']) != 1:
            fail('Unsupported or edited hook context: ' + hook['id'])
        return text.replace(hook['anchor'], block + hook['anchor'], 1).encode()
    if text.count(block) != 1:
        fail('Owned hook was edited or removed: ' + hook['id'])
    return text.replace(block, '', 1).encode()


def preflight_target(root, metadata):
    plain(root)
    if not root.is_dir() or root == Path('/'):
        fail('Target must be an explicit existing ii shell root')
    for relative, checksum in metadata.get('nativeApiSHA256', {}).items():
        path = root / relative
        plain(path)
        if not path.is_file() or digest(path.read_bytes()) != checksum:
            fail('Unsupported or customized native API file; expected the pinned source: ' + relative)
    for relative in metadata['requiredShellFiles']:
        path = root / relative
        plain(path)
        if not path.is_file():
            fail('Required pinned shell dependency is missing: ' + relative)
    for relative in ['services/Syncshell.qml', 'modules/ii/bar/SyncshellIndicator.qml',
                     'modules/ii/bar/SyncshellPopup.qml']:
        if (root / relative).exists():
            fail('Obsolete overlay collision: remove its exact owned hooks/files before installing: ' + relative)


def runtime_preflight(metadata):
    for command in ['quickshell', 'find', 'mkdir', 'xdg-open']:
        if not shutil.which(command):
            fail('Missing runtime command: ' + command)
    qtpaths = shutil.which('qtpaths6') or '/usr/lib/qt6/bin/qtpaths'
    try:
        qml = Path(subprocess.check_output([qtpaths, '--query', 'QT_INSTALL_QML'], text=True).strip())
    except (OSError, subprocess.CalledProcessError):
        fail('Qt 6 qtpaths is required to check runtime imports')
    for module in metadata['qtImports']:
        if not (qml / module / 'qmldir').is_file():
            fail('Missing Qt runtime import: ' + module)


def prepare(root, payload, remove):
    owned = root / 'syncshell'
    installed = owned.exists()
    old = None
    if installed:
        if not (owned / RECEIPT).is_file():
            fail('Unowned syncshell directory collision')
        old = read_json(owned / RECEIPT)
        verify_payload(owned, old['checksums'])
        if old['hooks'] != read_json(owned / 'compatibility.json')['hooks']:
            fail('Installation receipt hooks do not match the owned metadata')
    elif remove:
        fail('Syncshell is not installed')
    metadata = read_json((owned if remove else payload) / 'compatibility.json')
    if not remove:
        preflight_target(root, metadata)
    new_sums = None if remove else verify_payload(payload)
    if not remove:
        build = read_json(payload / 'build.json')
        if build['architecture'] != platform.machine():
            fail('Payload architecture does not match this host')
        probe = subprocess.run([str(payload / 'bin/syncshell-core')], capture_output=True, text=True, timeout=5)
        if probe.returncode != 1 or 'expected probe, status, stream' not in probe.stderr:
            fail('Bundled Go core could not execute on this host')
    changes = {}
    for hook in (old['hooks'] if old else []) + ([] if remove else metadata['hooks']):
        if hook['path'] not in HOOK_PATHS:
            fail('Unsupported integration hook path')
        path = root / hook['path']
        plain(path)
        if hook['path'] not in changes:
            data = path.read_bytes()
            changes[hook['path']] = {'old': data, 'new': data, 'mode': stat.S_IMODE(path.stat().st_mode)}
    if old:
        for hook in reversed(old['hooks']):
            entry = changes[hook['path']]
            entry['new'] = transform(entry['new'], hook, False)
    if not remove:
        for hook in metadata['hooks']:
            entry = changes[hook['path']]
            entry['new'] = transform(entry['new'], hook, True)
    receipt = None if remove else {'version': 1, 'hooks': metadata['hooks'], 'checksums': new_sums}
    return changes, receipt, installed


def recover(root):
    transaction = root / TRANSACTION
    record = read_json(transaction / 'transaction.json')
    # Check every file before reverting any; a crash never grants permission to
    # overwrite edits made after the transaction stopped.
    if set(record['files']) != HOOK_PATHS:
        fail('Invalid recovery hook paths')
    for relative, entry in record['files'].items():
        if digest(base64.b64decode(entry['old'])) != entry['oldHash']:
            fail('Invalid recovery file checksum: ' + relative)
        path = root / relative
        plain(path)
        current = digest(path.read_bytes())
        if current not in (entry['oldHash'], entry['newHash']):
            fail('Recovery conflict; preserve and resolve edits in ' + relative)
    owned = root / 'syncshell'
    if owned.exists():
        verify_payload(owned)
    if (transaction / 'previous').exists():
        verify_payload(transaction / 'previous')
    for relative, entry in record['files'].items():
        atomic(root / relative, base64.b64decode(entry['old']), entry['mode'])
    if (transaction / 'previous').exists():
        if owned.exists():
            shutil.rmtree(owned)
        os.replace(transaction / 'previous', owned)
    elif not record['installed'] and owned.exists():
        shutil.rmtree(owned)
    shutil.rmtree(transaction)


def transact(root, payload, remove, fail_after=None):
    transaction = root / TRANSACTION
    if transaction.exists():
        fail('Interrupted transaction exists; run recover before changing the installation')
    changes, receipt, installed = prepare(root, payload, remove)
    transaction.mkdir(mode=0o700)
    record = {'installed': installed, 'files': {relative: {
        'old': base64.b64encode(entry['old']).decode(), 'oldHash': digest(entry['old']),
        'newHash': digest(entry['new']), 'mode': entry['mode']}
        for relative, entry in changes.items()}}
    atomic(transaction / 'transaction.json', (json.dumps(record) + '\n').encode(), 0o600)
    try:
        if not remove:
            shutil.copytree(payload, transaction / 'next')
            atomic(transaction / 'next' / RECEIPT, (json.dumps(receipt, indent=2) + '\n').encode())
            verify_payload(transaction / 'next')
        owned = root / 'syncshell'
        if installed:
            os.replace(owned, transaction / 'previous')
        if not remove:
            os.replace(transaction / 'next', owned)
        for index, (relative, entry) in enumerate(changes.items(), 1):
            atomic(root / relative, entry['new'], entry['mode'])
            if fail_after == index:
                raise OSError('Injected installation failure')
        # Mark completion before deleting the recovery data.
        atomic(transaction / 'committed', b'complete\n', 0o600)
    except BaseException:
        recover(root)
        raise
    shutil.rmtree(transaction)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['check', 'install', 'remove', 'recover'])
    parser.add_argument('--target', type=Path, required=True)
    parser.add_argument('--payload', type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument('--shell-stopped', action='store_true', help='Confirm ii is stopped for a coherent file update')
    args = parser.parse_args()
    root = args.target.absolute()
    plain(root)
    if args.action != 'check' and not args.shell_stopped:
        fail('Stop ii first, then pass --shell-stopped; this tool never restarts your desktop')
    if args.action == 'recover':
        transaction = root / TRANSACTION
        if (transaction / 'committed').exists():
            shutil.rmtree(transaction)
        else:
            recover(root)
    elif (root / TRANSACTION).exists():
        fail('Interrupted transaction exists; run recover before changing the installation')
    elif args.action == 'check':
        metadata = read_json(args.payload / 'compatibility.json')
        runtime_preflight(metadata)
        prepare(root, args.payload, False)
    else:
        metadata = read_json((root / 'syncshell' if args.action == 'remove' else args.payload) / 'compatibility.json')
        if args.action == 'install':
            runtime_preflight(metadata)
        transact(root, args.payload, args.action == 'remove')
    print('[ok] ' + args.action)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, json.JSONDecodeError) as error:
        print('syncshell: ' + str(error), file=sys.stderr)
        sys.exit(1)
