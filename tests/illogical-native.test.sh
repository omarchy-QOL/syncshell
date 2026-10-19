#!/bin/bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_root=${1:?usage: illogical-native.test.sh PINNED_II_SHELL_ROOT}
work=${SYNCSHELL_NATIVE_ARTIFACTS:-$(mktemp -d /tmp/syncshell-ii-native.XXXXXX)}
mkdir -p "$work/captures"
if [[ -z ${SYNCSHELL_NATIVE_ARTIFACTS:-} ]]; then trap 'rm -rf -- "$work"' EXIT; fi
bash "$root/integrations/illogical-impulse/assemble.sh"
python3 "$root/tests/illogical/prepare_sdk.py" "$source_root" "$work" --components
if ! env -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
    QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= QT_STYLE_OVERRIDE=Fusion \
    SYNCSHELL_CAPTURE_DIR="$work/captures" QT_QUICK_BACKEND=software XDG_CONFIG_HOME="$work/config" \
    XDG_STATE_HOME="$work/state" XDG_CACHE_HOME="$work/cache" \
    timeout 150s quickshell --no-color -p "$work/qs/shell.qml" >"$work/log" 2>&1; then
  cat "$work/log"
  exit 1
fi
cat "$work/log"
# The pinned WTextField assigns a color to palette.active, a Qt color group.
# Keep that upstream warning explicit; every adapter warning remains a failure.
if rg '(ERROR|WARN|\[fail\])' "$work/log" | \
    rg -v 'WTextField.qml\[15:[^]]*\]: Unable to assign QColor to QQuickColorGroup' | \
    rg -v 'QML FileView at @syncshell/hosts/illogical-impulse/controllers/SettingsController.qml\[[^]]*\]: Write of /tmp/[^ ]*/config/syncshell/illogical-impulse.json failed: Unknown error when opening file'; then
  exit 1
fi
rg -q '\[ok\] native controls, forms' "$work/log"

# The fixture deliberately makes its own settings directory unwritable once per family.
[[ $(rg -c '\[ok\] injected settings write failure retained draft' "$work/log") == 2 ]]
[[ $(rg -c 'QML FileView.*Write of .*illogical-impulse.json failed:' "$work/log") == 2 ]]
