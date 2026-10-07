#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
sdk=${CAELESTIA_SDK:?set CAELESTIA_SDK to the pinned shell checkout}
build=${CAELESTIA_SDK_BUILD:?set CAELESTIA_SDK_BUILD to an out-of-tree build directory}
[[ $(git -C "$sdk" rev-parse HEAD) == 4e288c54a3b039154d19fe8a2064a174eb634405 ]]
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cmake -S "$root/tests/caelestia-sdk" -B "$build" -G Ninja -DCAELESTIA_SDK="$sdk" >"$work/configure.log"
cmake --build "$build" -j 4 >"$work/build.log" 2>&1 || { cat "$work/build.log"; exit 1; }
for copy in first second; do
  bash "$root/integrations/caelestia/assemble.sh" "$work/$copy"
  (cd -- "$work/$copy" && sha256sum --quiet --check SHA256SUMS)
done
diff -qr "$work/first" "$work/second"
ln -s -- "$work/first" "$work/linked"
for package in "$work/first" "$work/linked"; do
  "$build/syncshell-caelestia-probe" "$package" >"$work/types"
  if "$package/bin/syncshell-core" stream --help >"$work/stdout" 2>"$work/stderr"; then
    printf 'expected help to exit before starting a core session\n' >&2; exit 1
  fi
  grep -q 'syncshell-core: invalid command arguments' "$work/stderr"
done
mkdir -p "$work/loader-plugins" "$work/config/caelestia" "$work/data" "$work/cache"
ln -s "$work/first" "$work/loader-plugins/syncshell"
printf '%s\n' '{"enabled":["syncshell/syncshell"],"settings":{}}' >"$work/config/caelestia/plugins.json"
cat >"$work/Injected.qml" <<EOF_PROBE
import QtQuick
import Caelestia.Plugins
import "$work/first/hosts/caelestia/models/Ownership.js" as Ownership
Item {
    required property pluginEntryPoint entryPoint
    required property SettingsObject settings
    property int priorProbe: 0
    Component.onCompleted: {
        priorProbe = Ownership.view("loader-probe", { count: 0 }).count;
        Ownership.save("loader-probe", { count: priorProbe + 1 });
    }
}
EOF_PROBE
cat >"$work/Loader.qml" <<EOF_LOADER
import QtQuick
import Caelestia.Plugins
EntryPointLoader {
    entryPoint: Plugins.entryPoints(EntryPointType.BarEntry)[0]
    source: "Injected.qml"
}
EOF_LOADER
QT_QPA_PLATFORM=offscreen QML_IMPORT_PATH="$build/qml" \
  XDG_CONFIG_HOME="$work/config" XDG_DATA_HOME="$work/data" \
  XDG_CONFIG_DIRS="$work/config" XDG_DATA_DIRS="$work/data" \
  XDG_CACHE_HOME="$work/cache" CAELESTIA_PLUGIN_PATH="$work/loader-plugins" \
  "$build/syncshell-caelestia-loader" "$work/Loader.qml"
python3 "$root/tests/caelestia-imports.py" "$sdk" "$work/first" "$work/imports"
while IFS= read -r file; do
  [[ $file == *.qml ]] || continue
  /usr/lib/qt6/bin/qmlformat -n "$work/first/$file" >/dev/null
  /usr/lib/qt6/bin/qmllint --unqualified disable \
    -I "$work/imports" -I "$build/qml" \
    "$work/imports/syncshell/syncshell/$file"
done < "$root/integrations/caelestia/qml-files.txt"
# Run the actual controller against the named imports from the payload.
mkdir -p "$work/behavior"
sed 's|import "../../hosts/caelestia/controllers"|import syncshell.syncshell.hosts.caelestia.controllers|' \
  "$root/tests/caelestia/tst_panel.qml" >"$work/behavior/tst_panel.qml"
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner \
  -import "$work/imports" -input "$work/behavior"
node --test "$root/tests/caelestia-model.test.mjs" \
  "$root/tests/caelestia-ownership.test.mjs" "$root/tests/adapter-contract.test.mjs"
printf '[ok] Caelestia payload, SDK, behavior and reproducibility checks passed\n'
