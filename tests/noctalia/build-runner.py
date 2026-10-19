#!/usr/bin/env python3
"""Build offline checks against the pinned host VM, constructors and JSON codec."""
import pathlib
import json
import re
import subprocess
import sys

source, build, json_include = map(lambda value: pathlib.Path(value).resolve(), sys.argv[1:])
revision = subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip()
if revision != "8240b170dbbbf47b231170a795b24ae9ac7923f6":
    raise SystemExit("unexpected Noctalia source pin")
build.mkdir(parents=True, exist_ok=True)
host = (source / "src/scripting/luau_host.cpp").read_text()
start = host.index("  nlohmann::json luaToJson(")
end = host.index("  int luau_state_set(", start)
(build / "host-json.inc").write_text(host[start:end])
reconciler = (source / "src/ui/ui_tree_reconciler.cpp").read_text()
props = {name: re.findall(r'"([^"\n]+)"', body) for name, body in re.findall(
    r'static const std::unordered_set<std::string> k(\w+)\s*=\s*\{(.*?)\};', reconciler, re.S)}
mapping = {"column": "Flex", "row": "Flex", "scroll": "Scroll", "button": "Button", "label": "Label",
           "image": "Image", "glyph": "Glyph", "input": "Input", "toggle": "Toggle", "select": "Select"}
schema = {key: props[value] + ["key"] for key, value in mapping.items()}
(build / "host-props.inc").write_text('const char* hostProps = R"schema(' + json.dumps(schema) + ')schema";\n')
runner = pathlib.Path(__file__).with_name("runner.cpp").resolve()
luau = source / "third_party/luau"
libraries = ["Common", "Ast", "Bytecode", "Compiler", "VM"]
sources = [str(file) for name in libraries for file in sorted((luau / name / "src").glob("*.cpp"))]
includes = [str(luau / name / "include") for name in libraries]
includes += [str(luau / "VM/src"), str(build), str(json_include), str(source / "src")]
quote = lambda value: '"' + value.replace('"', '\\"') + '"'
(build / "CMakeLists.txt").write_text(
    "cmake_minimum_required(VERSION 3.16)\nproject(syncshell_native_checks CXX)\n"
    "set(CMAKE_CXX_STANDARD 20)\nadd_executable(native-luau\n"
    + "\n".join(map(quote, [str(runner)] + sources)) + ")\n"
    + "target_include_directories(native-luau PRIVATE " + " ".join(map(quote, includes)) + ")\n"
)
subprocess.run(["cmake", "-S", str(build), "-B", str(build), "-G", "Ninja", "-DCMAKE_BUILD_TYPE=Release"], check=True)
subprocess.run(["cmake", "--build", str(build), "--parallel", "4"], check=True)
