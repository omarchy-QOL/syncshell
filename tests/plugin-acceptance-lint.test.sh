#!/bin/bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
qmllint=${QMLLINT:-/usr/lib/qt6/bin/qmllint}
[[ -x $qmllint ]] || {
  printf 'Qt 6 qmllint is unavailable: %s\n' "$qmllint" >&2
  exit 1
}

qt_qml=/usr/lib/qt6/qml
if command -v qtpaths6 >/dev/null 2>&1; then
  qt_qml=$(qtpaths6 --query QT_INSTALL_QML)
elif command -v qmake6 >/dev/null 2>&1; then
  qt_qml=$(qmake6 -query QT_INSTALL_QML)
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -- "$repo_root/tests/plugin-acceptance.qml" "$tmp/shell.qml"
ln -s -- "$repo_root/hosts" "$tmp/hosts"
ln -s -- "$repo_root/shared" "$tmp/shared"
mkdir -p -- "$tmp/imports"
ln -s -- /usr/share/omarchy/shell "$tmp/imports/qs"

if ! output=$(
  "$qmllint" \
    -I "$qt_qml" \
    -I "$tmp/imports" \
    -I /usr/share/omarchy/shell \
    -I "$tmp" \
    "$tmp/shell.qml" 2>&1
); then
  printf '%s\n' "$output" >&2
  exit 1
fi
if [[ -n $output ]]; then
  printf '%s\n' "$output" >&2
  exit 1
fi
printf '[ok] staged plugin acceptance QML lint passed\n'
