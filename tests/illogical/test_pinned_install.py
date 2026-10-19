#!/usr/bin/env python3
"""Verify installation on a disposable copy of the actual pinned shell."""
import importlib.util
from pathlib import Path
import shutil
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('manage', ROOT / 'integrations/illogical-impulse/manage.py')
manage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manage)
payload = ROOT / 'dist/illogical-impulse'
metadata = manage.read_json(payload / 'compatibility.json')
manage.runtime_preflight(metadata)
with tempfile.TemporaryDirectory(prefix='syncshell-pinned-install-') as temporary:
    target = Path(temporary) / 'ii'
    shutil.copytree(Path(sys.argv[1]), target)
    before = {path: (target / path).read_bytes() for path in manage.HOOK_PATHS}
    manage.prepare(target, payload, False)
    manage.transact(target, payload, False)
    manage.transact(target, payload, False)
    manage.transact(target, payload, True)
    assert all((target / path).read_bytes() == content for path, content in before.items())
    assert not (target / 'syncshell').exists()
print('[ok] actual pinned source: check, install, repeat and byte-exact hook removal')
