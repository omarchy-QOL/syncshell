#!/usr/bin/env python3
"""Drive native production controls through a real Go child and disposable API."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from fake_syncthing import FakeSyncthing

ROOT = Path(__file__).resolve().parents[2]
PIN = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT.parent / 'syncshell/TODO/external/illogical-impulse/dots/.config/quickshell/ii'


def run_family(work, family):
    work.mkdir(parents=True)
    api = FakeSyncthing(work)
    try:
        subprocess.run(['python3', str(ROOT / 'tests/illogical/prepare_sdk.py'), str(PIN), str(work), '--components'], check=True)
        shutil.copy2(ROOT / 'tests/illogical/real-core.qml', work / 'qs/shell.qml')
        environment = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='',
            QT_STYLE_OVERRIDE='Fusion', QT_QUICK_BACKEND='software', SYNCSHELL_FIXTURE_CONFIG=str(api.config),
            SYNCSHELL_FIXTURE_WORK=str(work), SYNCSHELL_FIXTURE_FAMILY=family,
            XDG_CONFIG_HOME=str(work / 'config'), XDG_STATE_HOME=str(work / 'state'), XDG_CACHE_HOME=str(work / 'cache'))
        for variable in ['WAYLAND_DISPLAY', 'DISPLAY', 'HYPRLAND_INSTANCE_SIGNATURE']:
            environment.pop(variable, None)
        with (work / 'runtime.log').open('w') as log:
            process = subprocess.Popen(['quickshell', '--no-color', '-p', str(work / 'qs/shell.qml')],
                                       env=environment, stdout=log, stderr=subprocess.STDOUT)
            try:
                code = process.wait(timeout=100)
            except subprocess.TimeoutExpired:
                process.terminate()
                code = process.wait(timeout=10)
                raise AssertionError((work / 'runtime.log').read_text())
        output = (work / 'runtime.log').read_text()
        (work / 'mutations.json').write_text(__import__('json').dumps(api.mutations, indent=2) + '\n')
        print(output, end='')
        assert code == 0 and '[ok] real Go child' in output, output
        assert api.key not in output, 'credential exposed in public output'
        warnings = [line for line in output.splitlines() if 'WARN' in line or 'ERROR' in line]
        assert all(re.search(r'WTextField.qml\[15:[^]]*\]: Unable to assign QColor to QQuickColorGroup', line)
                   for line in warnings), warnings
        assert api.sentinel.read_text() == 'user files survive forgetting\n'
        assert not api.errors and api.theme == 'default' and 'folder' not in api.folders
        assert api.new not in api.devices and api.pending in api.devices
        assert api.dismiss not in api.pending_devices
        assert api.folders['newfolder']['path'] == str(work / 'created')
        assert (work / 'created').is_dir()
        assert [member['deviceID'] for member in api.folders['newfolder']['devices']] == [api.local]
        assert api.peer in [member['deviceID'] for member in api.folders['offered']['devices']]
        remaining = api.pending_folders['dismiss-offer']['offeredBy']
        assert list(remaining) == [api.peer], remaining
        assert sorted(path.name for path in api.assets.iterdir()) == ['another-adapter']
        writes = api.mutations
        assert sum(row['method'] == 'POST' and row['path'] == '/rest/config/folders' for row in writes) == 2
        assert sum(row['method'] == 'POST' and row['path'] == '/rest/config/devices' for row in writes) == 2
        scans = [row for row in writes if row['path'] == '/rest/db/scan']
        assert len(scans) == 2 and all(row['query'].get('folder') == ['folder'] for row in scans), scans
        assert any(row['path'] == '/rest/cluster/pending/folders' and row['query'] ==
                   {'folder': ['dismiss-offer'], 'device': [api.pending]} for row in writes)
        settings = __import__('json').loads((work / 'config/syncshell/illogical-impulse.json').read_text())
        assert settings['webUi'] == 'default'
        api.theme = 'syncshell-illogical-impulse-modern'
        cleanup = subprocess.run(['python3', str(work / 'qs/syncshell/cleanup-profile.py'), '--config', str(api.config)],
                                 capture_output=True, text=True, timeout=15)
        assert cleanup.returncode == 0 and api.theme == 'default', cleanup.stderr
        probe = subprocess.run(['pgrep', '-f', str(work / 'qs/syncshell/bin/syncshell-core')], capture_output=True)
        assert probe.returncode == 1, 'Go core child was orphaned'
        (work / 'mutations.json').write_text(__import__('json').dumps(writes, indent=2) + '\n')
        print(f'[ok] {family}: exact API mutations, preserved files, sharing, profile recovery, cleanup and worker exit')
    finally:
        api.close()


if __name__ == '__main__':
    output = os.environ.get('SYNCSHELL_CORE_ARTIFACTS')
    if output:
        for family in ['ii', 'waffle']:
            run_family(Path(output) / family, family)
    else:
        with tempfile.TemporaryDirectory(prefix='syncshell-ii-core-') as temp:
            for family in ['ii', 'waffle']:
                run_family(Path(temp) / family, family)
