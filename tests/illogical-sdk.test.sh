#!/bin/bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_root=${1:?usage: illogical-sdk.test.sh PINNED_II_SHELL_ROOT}
work=$(mktemp -d /tmp/syncshell-ii-sdk.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
bash "$root/integrations/illogical-impulse/assemble.sh"
python3 "$root/tests/illogical/prepare_sdk.py" "$source_root" "$work"
mapfile -d '' files < <(find "$work/qs/syncshell/hosts/illogical-impulse" -name '*.qml' -print0)
# Host tokens and Loader.item are intentionally dynamic. Quickshell registers
# its PanelWindow backend at runtime, outside Qt's static type metadata.
if ! /usr/lib/qt6/bin/qmllint -I "$work" -W 0 \
    --missing-property info --unqualified info --signal-handler-parameters info \
    --uncreatable-type info "${files[@]}" >"$work/lint" 2>&1; then
  rg -A 8 "Warning:|Error:" "$work/lint" || tail -40 "$work/lint"
  exit 1
fi
printf '[ok] SDK-aware imports and QML types checked against pinned native libraries\n'
