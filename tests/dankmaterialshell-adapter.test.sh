#!/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT

bash "$root/integrations/dankmaterialshell/assemble.sh" "$work/Syncshell"
jq -e --arg version "$(jq -er .version "$root/manifest.json")" \
  '.version == $version and .requires_dms == ">=1.6.2" and
   .type == "composite" and .id == "syncshell" and
   (.permissions | index("settings_write")) != null' \
  "$work/Syncshell/plugin.json" >/dev/null
test -x "$work/Syncshell/bin/syncshell-core"
test -x "$work/Syncshell/bin/x86_64/syncshell-core"
test -x "$work/Syncshell/bin/aarch64/syncshell-core"
test -f "$work/Syncshell/shared/AdapterService.qml"
test -f "$work/Syncshell/shared/RescanTracker.qml"
while IFS= read -r path; do
  test -f "$work/Syncshell/${path#./}"
done < <(jq -r '.components[], .settings' "$work/Syncshell/plugin.json")
test ! -e "$work/Syncshell/SyncshellWidget.qml"
test ! -e "$work/Syncshell/SyncshellDaemon.qml"
test -f "$work/Syncshell/assets/mono/status-default.svg"
test -f "$work/Syncshell/webui/manifest.json"
test -f "$work/Syncshell/LICENSE"
test -f "$work/Syncshell/packaging/bundled/LICENSE.golang"
jq -e '.format == 1 and .dmsSDK == "1.6.2" and
  (.recipeSha256 | test("^[a-f0-9]{64}$")) and .webUi.version != null' \
  "$work/Syncshell/ASSEMBLY.json" >/dev/null
(cd -- "$work/Syncshell" && sha256sum --quiet --check PACKAGE-SHA256SUMS)
bash "$root/integrations/dankmaterialshell/assemble.sh" "$work/repeated"
diff -qr "$work/Syncshell" "$work/repeated"
diff -qr "$work/Syncshell" "$root/dist/dankmaterialshell"
if bash "$root/integrations/dankmaterialshell/assemble.sh" "$work/Syncshell" 2>/dev/null; then
  printf 'assembler overwrote a nonempty package\n' >&2
  exit 1
fi
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input "$root/tests/dms"
node --test "$root/tests/adapter-contract.test.mjs" "$root"/tests/dms-*.test.mjs
printf '[ok] DMS adapter bundle contract passed\n'
