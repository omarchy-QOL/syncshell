#!/usr/bin/env python3
"""Import one verified Web UI release into the plugin checkout."""

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import tarfile
import tempfile
import urllib.request


def import_release(root, version, expected, archive):
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?", version):
        raise ValueError("invalid release version")
    if not re.fullmatch(r"[a-f0-9]{64}", expected):
        raise ValueError("expected SHA-256 must be 64 lowercase hex digits")
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    if digest != expected:
        raise ValueError("archive checksum mismatch; existing bundle retained")
    target = root / "webui"
    if target.is_symlink() or (target.exists() and not target.is_dir()):
        raise ValueError("webui must be a regular directory")
    with tempfile.TemporaryDirectory(prefix=".webui-import-", dir=root) as temporary:
        staging = Path(temporary)
        name = "syncshell-webui-v" + version
        with tarfile.open(archive, "r:gz") as source:
            seen = set()
            for member in source.getmembers():
                path = PurePosixPath(member.name)
                if (path.is_absolute() or ".." in path.parts
                        or not path.parts or path.parts[0] != name
                        or not (member.isfile() or member.isdir())
                        or member.name in seen):
                    raise ValueError("unexpected archive entry: " + member.name)
                seen.add(member.name)
                destination = staging.joinpath(*path.parts)
                if member.isdir():
                    destination.mkdir(parents=True, exist_ok=True)
                else:
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    with source.extractfile(member) as data, destination.open("wb") as output:
                        shutil.copyfileobj(data, output)
                    destination.chmod(0o644)
        bundle = staging / name
        manifest = json.loads((bundle / "manifest.json").read_text())
        if (manifest.get("name") != "syncshell-webui"
                or manifest.get("version") != version
                or manifest.get("integrationFormat") != 1
                or not re.fullmatch(r"[a-f0-9]{40}", manifest.get("source", ""))):
            raise ValueError("unsupported or mismatched release manifest")
        required = ["gui/syncshell-modern/index.html", "integration/omarchy-theme.css.in",
                    "integration/omarchy-theme-refresh.js", "install.sh"]
        for path in required:
            if not (bundle / path).is_file():
                raise ValueError("release is missing " + path)
        listed = set()
        for line in (bundle / "SHA256SUMS").read_text().splitlines():
            checksum, path = line.split("  ", 1)
            rel = PurePosixPath(path)
            if rel.is_absolute() or ".." in rel.parts or path in listed:
                raise ValueError("invalid checksum entry")
            listed.add(path)
            if hashlib.sha256((bundle / path).read_bytes()).hexdigest() != checksum:
                raise ValueError("asset checksum mismatch: " + path)
        actual = {p.relative_to(bundle).as_posix() for p in bundle.rglob("*") if p.is_file()}
        if listed != actual - {"SHA256SUMS"}:
            raise ValueError("release checksum inventory is incomplete")
        record = {"version": version, "source": manifest["source"], "sha256": expected}
        (bundle / "import.json").write_text(json.dumps(record, indent=2) + "\n")
        # Preserve source payload checksums and include the local import record.
        with (bundle / "SHA256SUMS").open("a") as sums:
            sums.write(hashlib.sha256((bundle / "import.json").read_bytes()).hexdigest()
                       + "  import.json\n")
        previous = staging / "previous"
        if target.exists():
            target.rename(previous)
        try:
            bundle.rename(target)
        except BaseException:
            if previous.exists():
                previous.rename(target)
            raise
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--archive", type=Path, help="local archive instead of GitHub download")
    parser.add_argument("--repo", default="syncshell/syncshell-webui")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    with tempfile.TemporaryDirectory(prefix="syncshell-webui-download-") as temporary:
        archive = args.archive
        if archive is None:
            if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repo):
                parser.error("invalid GitHub repository")
            if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?", args.version):
                parser.error("invalid release version")
            archive = Path(temporary) / "release.tar.gz"
            url = (f"https://github.com/{args.repo}/releases/download/v{args.version}/"
                   f"syncshell-webui-v{args.version}.tar.gz")
            with urllib.request.urlopen(url, timeout=60) as response, archive.open("wb") as output:
                shutil.copyfileobj(response, output)
        print(json.dumps(import_release(root, args.version, args.sha256, archive), indent=2))


if __name__ == "__main__":
    main()
