#!/usr/bin/env python3
"""Assemble the native module without copying host libraries or rewriting QML."""
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def checksums(root):
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(root.rglob('*')) if p.is_file() and p.name != 'SHA256SUMS.json'}


def assemble():
    output = ROOT / 'dist/illogical-impulse'
    output.parent.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.illogical-', dir=output.parent) as temporary:
        stage = Path(temporary) / 'package'
        stage.mkdir()
        for name in ['hosts/illogical-impulse', 'shared', 'webui']:
            shutil.copytree(ROOT / name, stage / name)
        (stage / 'assets/mono').mkdir(parents=True)
        for path in (ROOT / 'assets').glob('status-*.svg'):
            shutil.copy2(path, stage / 'assets' / path.name)
        for path in (ROOT / 'assets/mono').glob('status-*.svg'):
            shutil.copy2(path, stage / 'assets/mono' / path.name)
        shutil.copy2(ROOT / 'LICENSE', stage / 'LICENSE')
        host = stage / 'hosts/illogical-impulse'
        for directory in [host] + [p for p in host.rglob('*') if p.is_dir()]:
            suffix = '.'.join(p.capitalize() for p in directory.relative_to(host).parts)
            lines = ['module Syncshell.Illogical' + ('.' + suffix if suffix else '')]
            for path in sorted(directory.glob('*.qml')):
                if path.name == 'Registry.qml':
                    continue
                lines.append(f'{path.stem} 1.0 {path.name}')
            (directory / 'qmldir').write_text('\n'.join(lines) + '\n')
        (stage / 'shared/qmldir').write_text('module Syncshell.Shared\n' +
            ''.join(f'{path.stem} 1.0 {path.name}\n' for path in sorted((stage / 'shared').glob('*.qml'))))
        (stage / 'qmldir').write_text('module qs.syncshell\n'
            'singleton Registry 1.0 hosts/illogical-impulse/Registry.qml\n'
            'IllogicalHost 1.0 hosts/illogical-impulse/IllogicalHost.qml\n'
            'IllogicalBarEntry 1.0 hosts/illogical-impulse/IllogicalBarEntry.qml\n')
        (stage / 'bin').mkdir()
        environment = dict(os.environ, CGO_ENABLED='0', GOOS='linux',
                           GOARCH={'x86_64': 'amd64', 'aarch64': 'arm64'}[platform.machine()])
        subprocess.run(['go', 'build', '-trimpath', '-o', str(stage / 'bin/syncshell-core'),
                        './cmd/syncshell-core'], cwd=ROOT / 'core', env=environment, check=True)
        for name in ['manage.py', 'cleanup-profile.py', 'compatibility.json']:
            shutil.copy2(Path(__file__).parent / name, stage / name)
        (stage / 'build.json').write_text(json.dumps({
            'revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
            'uncommitted': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT)),
            'architecture': platform.machine(),
            'go': subprocess.check_output(['go', 'version'], text=True).strip()}, indent=2) + '\n')
        (stage / 'SHA256SUMS.json').write_text(json.dumps(checksums(stage), indent=2) + '\n')
        if output.exists():
            shutil.rmtree(output)
        os.replace(stage, output)
    print(output)


if __name__ == '__main__':
    assemble()
