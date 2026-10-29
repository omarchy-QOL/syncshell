#!/usr/bin/env python3
"""Generate tooling metadata from the exact source and assembled payload."""
import pathlib
import shutil
import sys

sdk, payload, target = map(pathlib.Path, sys.argv[1:])
for source, destination, prefix in (
    (sdk, target / 'qs', 'qs'),
    (payload, target / 'syncshell' / 'syncshell', 'syncshell.syncshell'),
):
    for path in source.rglob('*'):
        if path.suffix not in ('.qml', '.js') or '.git' in path.parts:
            continue
        relative = path.relative_to(source)
        if source == sdk and relative.parts[0] not in ('components', 'services', 'modules', 'utils'):
            continue
        output = destination / relative
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, output)
    for directory in [destination] + sorted(p for p in destination.rglob('*') if p.is_dir()):
        relative = directory.relative_to(destination)
        uri = '.'.join((prefix, *relative.parts))
        lines = ['module ' + uri]
        for path in sorted(directory.glob('*.qml')):
            if not path.stem[0].isupper():
                continue
            singleton = 'singleton ' if 'pragma Singleton' in path.read_text() else ''
            lines.append(singleton + path.stem + ' 1.0 ' + path.name)
        (directory / 'qmldir').write_text('\n'.join(lines) + '\n')
