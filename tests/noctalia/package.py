#!/usr/bin/env python3
"""Check the assembled payload without launching Noctalia or Syncthing."""
import json
import pathlib
import re
import sys
import tomllib

root = pathlib.Path(sys.argv[1]).resolve()
manifest = tomllib.loads((root / "plugin.toml").read_text())
assert manifest["id"] == "syncshell/syncshell"
assert manifest["plugin_api"] == 31
assert re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", manifest["version"])
keys = manifest["panel"][0]["capture_keys"]
assert "Return" not in keys and "Up" not in keys and "Down" not in keys, "capture steals editor keys"
assert {"Alt+Up", "Alt+Down", "Alt+Return", "Alt+Left"}.issubset(keys)
settings = {setting["key"]: setting for setting in manifest["setting"]}
assert settings["refreshSeconds"]["min"] == 60
assert settings["serviceState"]["default"] == "enabled"
translations = json.loads((root / "translations/en.json").read_text())
for kind in ("service", "widget", "panel"):
    assert len(manifest[kind]) == 1, kind
    for entry in manifest[kind]:
        path = root / entry["entry"]
        assert path.suffix == ".luau" and path.is_file() and path.is_relative_to(root)
for setting in manifest["setting"]:
    assert setting["label_key"] in translations
    for option in setting.get("options", []):
        assert option["label_key"] in translations
for path in root.rglob("*"):
    assert not path.is_symlink(), f"linked payload: {path}"
    assert path.suffix not in (".qml", ".go", ".cpp"), f"unexpected runtime dependency: {path}"
    assert path.name not in ("TODO", "tests", ".git"), f"unexpected payload: {path}"
for path in (root / "hosts/noctalia").rglob("*.luau"):
    for relative in re.findall(r'require\("([^"\n]+)"\)', path.read_text()):
        module = (path.parent / relative).resolve()
        assert module.is_relative_to(root) and module.is_file(), f"unresolved module: {module}"
binary = root / "bin/syncshell-core"
assert binary.stat().st_mode & 0o111
assert binary.read_bytes()[:4] == b"\x7fELF"
assert (root / "webui/gui/syncshell-modern/index.html").is_file()
assert (root / "LICENSE").is_file()
print("Noctalia manifest and payload checks passed")
