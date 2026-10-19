#!/usr/bin/env python3
"""Stage the pinned libraries for SDK checks and isolated component execution."""
import argparse
from pathlib import Path
import re
import shutil

parser = argparse.ArgumentParser()
parser.add_argument('source', type=Path)
parser.add_argument('destination', type=Path)
parser.add_argument('--components', action='store_true')
parser.add_argument('--owner', action='store_true')
args = parser.parse_args()
repo = Path(__file__).resolve().parents[2]
root = args.destination / 'qs'
shutil.copytree(args.source, root, ignore=shutil.ignore_patterns('.git', 'qmldir'))
shutil.copytree(repo / 'dist/illogical-impulse', root / 'syncshell')
for directory in [root] + [p for p in root.rglob('*') if p.is_dir() and 'syncshell' not in p.relative_to(root).parts]:
    files = sorted(directory.glob('*.qml'))
    if not files: continue
    lines = ['module ' + '.'.join(directory.relative_to(args.destination).parts)]
    for file in files:
        if not file.stem[0].isupper(): continue
        singleton = 'singleton ' if re.search(r'^pragma Singleton', file.read_text(), re.M) else ''
        lines.append(f'{singleton}{file.stem} 1.0 {file.name}')
    (directory / 'qmldir').write_text('\n'.join(lines) + '\n')
if args.components or args.owner:
    # Keep desktop services outside this fixture. Native controls, Config,
    # Appearance and Looks execute unchanged; only path IO is isolated.
    for directory, module in [(root, 'qs'), (root / 'services', 'qs.services')]:
        (directory / 'FixtureBoundary.qml').write_text('import QtQuick\nQtObject {}\n')
        (directory / 'qmldir').write_text(f'module {module}\nFixtureBoundary 1.0 FixtureBoundary.qml\n')
    common = root / 'modules/common'
    (common / 'qmldir').write_text('module qs.modules.common\n'
        'singleton Appearance 1.0 Appearance.qml\nsingleton Config 1.0 Config.qml\n'
        'singleton Directories 1.0 Directories.qml\n')
    (common / 'functions/qmldir').write_text('module qs.modules.common.functions\n'
        'singleton ColorUtils 1.0 ColorUtils.qml\nsingleton FileUtils 1.0 FileUtils.qml\n')
    paths = {'shellConfigPath': str(args.destination / 'config.json'), 'assetsPath': str(root / 'assets'),
             'home': 'file://' + str(args.destination), 'videos': 'file://' + str(args.destination)}
    (common / 'Directories.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject {\n' +
        '\n'.join(f'    readonly property string {key}: "{value}"' for key, value in paths.items()) + '\n}\n')
    (args.destination / 'config.json').write_text('{}\n')
    path = root / 'modules/waffle/looks/qmldir'
    path.write_text('\n'.join(line for line in path.read_text().splitlines()
                              if not line.startswith('singleton WIcons')) + '\n')
    shutil.copy2(repo / ('tests/illogical/owner-lifetime.qml' if args.owner else 'tests/illogical/native-components.qml'), root / 'shell.qml')
    if args.owner:
        (root / 'GlobalStates.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject {\n'
            'property bool screenLocked: false\nproperty bool overviewOpen: false\n'
            'property bool sidebarLeftOpen: false\nproperty bool sidebarRightOpen: false\n}\n')
        with (root / 'qmldir').open('a') as file:
            file.write('singleton GlobalStates 1.0 GlobalStates.qml\n')
        shutil.copy2(repo / 'tests/illogical/worker-mock.py', root / 'syncshell/bin/syncshell-core')
        (root / 'syncshell/bin/syncshell-core').chmod(0o755)
print(root)
