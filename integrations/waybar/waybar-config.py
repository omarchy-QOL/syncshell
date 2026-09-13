#!/usr/bin/env python3
import argparse
import json
import pathlib
import re
import shlex
import stat
import tempfile


MODULE_START = "// syncshell module start"
MODULE_END = "// syncshell module end"
PLACEMENT_START = "// syncshell placement start"
PLACEMENT_END = "// syncshell placement end"
STYLE_START = "/* syncshell style start */"
STYLE_END = "/* syncshell style end */"


def atomic_write(path: pathlib.Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o644
    descriptor, temporary = tempfile.mkstemp(dir=path.parent, prefix=".syncshell-")
    try:
        with open(descriptor, "w") as output:
            output.write(text)
        pathlib.Path(temporary).chmod(mode)
        pathlib.Path(temporary).replace(path)
    except BaseException:
        pathlib.Path(temporary).unlink(missing_ok=True)
        raise


def strip_marked(text: str, start: str, end: str) -> str:
    pattern = re.compile(
        r"[ \t]*" + re.escape(start) + r".*?" + re.escape(end)
        + r"[ \t]*\n?",
        re.DOTALL,
    )
    if (start in text) != (end in text):
        raise ValueError(f"incomplete managed block: {start}")
    return pattern.sub("", text)


def module_block(root: pathlib.Path) -> str:
    status = shlex.quote(str(root / "status.sh"))
    quickshell = "quickshell -p " + shlex.quote(str(root))
    values = {
        "return-type": "json",
        "exec": status,
        "on-click": quickshell + " ipc call syncshell toggle",
        "on-click-right": quickshell + " ipc call syncshell refresh",
        "on-click-middle": quickshell + " ipc call syncshell openWebUi",
        "tooltip": True,
    }
    encoded = json.dumps(values, indent=2)
    body = encoded[1:-1].strip()
    indented = "\n".join("  " + line for line in body.splitlines())
    return (
        f"\n  {MODULE_START}\n"
        f"  \"custom/syncshell\": {{\n{indented}\n  }},\n"
        f"  {MODULE_END}\n"
    )


def install_config(path: pathlib.Path, root: pathlib.Path) -> None:
    if path.exists():
        text = path.read_text()
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        text = '{\n  "layer": "top",\n  "position": "top",\n' \
            '  "height": 34,\n  "modules-left": ["hyprland/workspaces"],\n' \
            '  "modules-right": []\n}\n'
    text = strip_marked(text, MODULE_START, MODULE_END)
    text = strip_marked(text, PLACEMENT_START, PLACEMENT_END)
    opening = text.find("{")
    if opening < 0:
        raise ValueError("Waybar config has no object")
    text = text[: opening + 1] + module_block(root) + text[opening + 1 :]
    modules = re.search(r'("modules-right"\s*:\s*\[)', text)
    placement = (
        f"\n    {PLACEMENT_START}\n"
        '    "custom/syncshell",\n'
        f"    {PLACEMENT_END}"
    )
    if modules:
        end = modules.end()
        text = text[:end] + placement + text[end:]
    else:
        addition = (
            f"\n  {PLACEMENT_START}\n"
            '  "modules-right": ["custom/syncshell"],\n'
            f"  {PLACEMENT_END}\n"
        )
        opening = text.find("{")
        text = text[: opening + 1] + addition + text[opening + 1 :]
    atomic_write(path, text)


def remove_config(path: pathlib.Path) -> None:
    if not path.exists():
        return
    text = path.read_text()
    text = strip_marked(text, MODULE_START, MODULE_END)
    text = strip_marked(text, PLACEMENT_START, PLACEMENT_END)
    atomic_write(path, text)


def install_style(path: pathlib.Path) -> None:
    text = path.read_text() if path.exists() else ""
    text = strip_marked(text, STYLE_START, STYLE_END)
    atomic_write(
        path,
        f'{STYLE_START}\n@import url("syncshell.css");\n{STYLE_END}\n'
        + text,
    )


def remove_style(path: pathlib.Path) -> None:
    if path.exists():
        atomic_write(
            path,
            strip_marked(path.read_text(), STYLE_START, STYLE_END),
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("install", "remove"))
    parser.add_argument("--config", type=pathlib.Path, required=True)
    parser.add_argument("--style", type=pathlib.Path, required=True)
    parser.add_argument("--root", type=pathlib.Path, required=True)
    args = parser.parse_args()
    if args.action == "install":
        install_config(args.config, args.root)
        install_style(args.style)
    else:
        remove_config(args.config)
        remove_style(args.style)


if __name__ == "__main__":
    main()
