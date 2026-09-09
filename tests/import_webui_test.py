import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("import_webui",
    Path(__file__).resolve().parents[1] / "scripts/import-webui.py")
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)


class ImportReleaseTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "webui").mkdir()
        (self.root / "webui/old").write_text("working")
        (self.root / "owner-file").write_text("retain")

    def archive(self, extra=None, integration=1):
        files = {
            "gui/syncshell-modern/index.html": b"new UI",
            "integration/omarchy-theme.css.in": b"body {}",
            "integration/omarchy-theme-refresh.js": b"refresh()",
            "install.sh": b"installer",
            "manifest.json": json.dumps({"name": "syncshell-webui", "version": "0.1.0",
                "source": "a" * 40, "integrationFormat": integration}).encode(),
        }
        files["SHA256SUMS"] = "".join(hashlib.sha256(value).hexdigest()
            + "  " + key + "\n" for key, value in files.items()).encode()
        archive = self.root / "release.tar.gz"
        with tarfile.open(archive, "w:gz") as output:
            for name, data in files.items():
                info = tarfile.TarInfo("syncshell-webui-v0.1.0/" + name)
                info.size = len(data)
                output.addfile(info, io.BytesIO(data))
            if extra:
                output.addfile(extra)
        return archive, hashlib.sha256(archive.read_bytes()).hexdigest()

    def test_update_removes_stale_assets_and_records_pin(self):
        archive, digest = self.archive()
        importer.import_release(self.root, "0.1.0", digest, archive)
        self.assertFalse((self.root / "webui/old").exists())
        self.assertEqual((self.root / "owner-file").read_text(), "retain")
        self.assertEqual(json.loads((self.root / "webui/import.json").read_text())["sha256"], digest)
        importer.import_release(self.root, "0.1.0", digest, archive)
        self.assertEqual((self.root / "webui/gui/syncshell-modern/index.html").read_text(), "new UI")

    def test_bad_checksum_retains_working_bundle(self):
        archive, _ = self.archive()
        with self.assertRaisesRegex(ValueError, "checksum mismatch"):
            importer.import_release(self.root, "0.1.0", "0" * 64, archive)
        self.assertEqual((self.root / "webui/old").read_text(), "working")

    def test_unsupported_contract_retains_working_bundle(self):
        archive, digest = self.archive(integration=2)
        with self.assertRaisesRegex(ValueError, "manifest"):
            importer.import_release(self.root, "0.1.0", digest, archive)
        self.assertEqual((self.root / "webui/old").read_text(), "working")

    def test_archive_cannot_escape_or_install_links(self):
        for name, kind in [("syncshell-webui-v0.1.0/../../owner-file", tarfile.REGTYPE),
                           ("syncshell-webui-v0.1.0/link", tarfile.SYMTYPE)]:
            info = tarfile.TarInfo(name)
            info.type, info.linkname = kind, "/tmp"
            archive, digest = self.archive(extra=info)
            with self.assertRaisesRegex(ValueError, "archive entry"):
                importer.import_release(self.root, "0.1.0", digest, archive)
            self.assertEqual((self.root / "webui/old").read_text(), "working")
            self.assertEqual((self.root / "owner-file").read_text(), "retain")

    def test_failed_replacement_restores_previous_bundle(self):
        archive, digest = self.archive()
        rename = Path.rename

        def fail_new_bundle(path, target):
            if path.name == "syncshell-webui-v0.1.0":
                raise OSError("simulated replacement failure")
            return rename(path, target)

        with patch.object(Path, "rename", fail_new_bundle):
            with self.assertRaisesRegex(OSError, "replacement failure"):
                importer.import_release(self.root, "0.1.0", digest, archive)
        self.assertEqual((self.root / "webui/old").read_text(), "working")


if __name__ == "__main__":
    unittest.main()
