#!/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$root"

# Models run in Qt, not a JavaScript surrogate with different import semantics.
QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
  /usr/lib/qt6/bin/qml tests/run.qml
node --test tests/folder-creation.test.mjs

# Run serially: popup focus tests share the desktop and are timing sensitive.
for name in architecture plugin-acceptance-lint \
  dropdown-search folder-overview busy-button \
  adapter-service core-process install-recovery refresh-recovery \
  rescan-core-loss self-removal settings-migration theme-palette \
  caelestia-adapter dankmaterialshell-adapter illogical-impulse-adapter \
  waybar-adapter; do
  printf '\n==> %s\n' "$name"
  bash "tests/$name.test.sh"
done
