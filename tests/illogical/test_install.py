#!/usr/bin/env python3
import importlib.util
import json
import multiprocessing
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('manage', ROOT / 'integrations/illogical-impulse/manage.py')
manage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manage)


class Installation(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / 'ii'
        self.root.mkdir()
        self.payload = ROOT / 'dist/illogical-impulse'
        # Hook fixtures isolate filesystem transactions from the separate real
        # pinned-source/import checks.
        self.payload = Path(self.temporary.name) / 'payload'
        shutil.copytree(ROOT / 'dist/illogical-impulse', self.payload)
        self.metadata = manage.read_json(self.payload / 'compatibility.json')
        self.metadata['nativeApiSHA256'] = {}
        (self.payload / 'compatibility.json').write_text(json.dumps(self.metadata))
        sums = manage.read_json(self.payload / 'SHA256SUMS.json')
        sums['compatibility.json'] = manage.digest((self.payload / 'compatibility.json').read_bytes())
        (self.payload / 'SHA256SUMS.json').write_text(json.dumps(sums))
        for relative in self.metadata['requiredShellFiles']:
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('// native fixture\n')
        for hook in self.metadata['hooks']:
            path = self.root / hook['path']
            with path.open('a') as file:
                file.write(hook['anchor'])
        self.original = {hook['path']: (self.root / hook['path']).read_bytes() for hook in self.metadata['hooks']}

    def install(self):
        manage.transact(self.root, self.payload, False)

    def test_install_repeat_update_remove_preserve_customization(self):
        self.install()
        self.install()
        shell = self.root / 'shell.qml'
        shell.write_text(shell.read_text() + '// my unrelated customization\n')
        self.install()
        manage.transact(self.root, self.payload, True)
        for relative, data in self.original.items():
            if relative == 'shell.qml': data += b'// my unrelated customization\n'
            self.assertEqual((self.root / relative).read_bytes(), data)
        self.assertFalse((self.root / 'syncshell').exists())
        self.assertFalse((self.root / manage.TRANSACTION).exists())

    def test_unowned_payload_collision(self):
        (self.root / 'syncshell').mkdir()
        with self.assertRaisesRegex(ValueError, 'Unowned'): self.install()

    def test_hook_edit_rejected_without_any_change(self):
        self.install()
        path = self.root / 'shell.qml'
        path.write_text(path.read_text().replace('Syncshell.IllogicalHost {}', 'Syncshell.IllogicalHost { enabled: false }'))
        previous = path.read_bytes()
        with self.assertRaisesRegex(ValueError, 'hook was edited'): self.install()
        self.assertEqual(path.read_bytes(), previous)

    def test_owned_file_customization_is_preserved_as_conflict(self):
        self.install()
        path = self.root / 'syncshell/hosts/illogical-impulse/IllogicalHost.qml'
        path.write_text(path.read_text() + '// local changes\n')
        with self.assertRaisesRegex(ValueError, 'checksum conflict'):
            manage.transact(self.root, self.payload, True)
        self.assertTrue(path.read_text().endswith('// local changes\n'))

    def test_failure_at_each_hook_restores_original_installation(self):
        self.install()
        original_receipt = (self.root / 'syncshell' / manage.RECEIPT).read_bytes()
        for step in range(1, 5):
            with self.assertRaisesRegex(OSError, 'Injected'):
                manage.transact(self.root, self.payload, False, fail_after=step)
            self.assertEqual((self.root / 'syncshell' / manage.RECEIPT).read_bytes(), original_receipt)
            manage.prepare(self.root, self.payload, False)
            self.assertFalse((self.root / manage.TRANSACTION).exists())

    def test_first_install_failure_removes_owned_payload(self):
        with self.assertRaises(OSError):
            manage.transact(self.root, self.payload, False, fail_after=2)
        self.assertFalse((self.root / 'syncshell').exists())
        for path, original in self.original.items():
            self.assertEqual((self.root / path).read_bytes(), original)

    def test_partial_hook_and_link_rejected(self):
        path = self.root / 'shell.qml'
        path.write_text(path.read_text() + '// syncshell begin entry-0\n')
        with self.assertRaisesRegex(ValueError, 'Partial'): self.install()
        path.unlink()
        path.symlink_to(self.payload / 'hosts/illogical-impulse/IllogicalHost.qml')
        with self.assertRaisesRegex(ValueError, 'linked'): self.install()

    def crash_update(self):
        original = manage.atomic
        def interrupted(path, data, mode=0o644):
            original(path, data, mode)
            if path == self.root / 'shell.qml':
                os._exit(77)
        manage.atomic = interrupted
        manage.transact(self.root, self.payload, False)

    def test_crash_recovery_preserves_installation_and_detects_new_edits(self):
        self.install()
        original = {path: (self.root / path).read_bytes() for path in self.original}
        child = multiprocessing.get_context('fork').Process(target=self.crash_update)
        child.start()
        child.join(10)
        self.assertEqual(child.exitcode, 77)
        with self.assertRaisesRegex(ValueError, 'Interrupted transaction'):
            self.install()
        path = self.root / 'shell.qml'
        previous = path.read_bytes()
        path.write_bytes(previous + b'// customization after crash\n')
        with self.assertRaisesRegex(ValueError, 'Recovery conflict'):
            manage.recover(self.root)
        self.assertTrue(path.read_bytes().endswith(b'// customization after crash\n'))
        path.write_bytes(previous)
        manage.recover(self.root)
        for relative, expected in original.items():
            self.assertEqual((self.root / relative).read_bytes(), expected)
        manage.prepare(self.root, self.payload, False)
        self.assertFalse((self.root / manage.TRANSACTION).exists())

    def test_remove_after_upstream_dependency_changes(self):
        self.install()
        path = self.root / 'modules/waffle/looks/WTextField.qml'
        path.unlink()
        manage.transact(self.root, self.payload, True)
        self.assertFalse((self.root / 'syncshell').exists())
        for relative, expected in self.original.items():
            self.assertEqual((self.root / relative).read_bytes(), expected)

    def test_missing_native_dependency_rejected(self):
        (self.root / 'modules/waffle/looks/WTextField.qml').unlink()
        with self.assertRaisesRegex(ValueError, 'dependency is missing'): self.install()


if __name__ == '__main__':
    unittest.main()
