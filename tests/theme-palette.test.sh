#!/bin/bash
set -euo pipefail

# shellcheck source=qml-test-helper.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/qml-test-helper.sh"
stage_qml_test theme-palette \
  hosts/omarchy/controllers/ThemePaletteController.qml \
  hosts/omarchy/models/ThemePaletteModel.js
export TEST_PALETTE_MODE=$test_root/mode
export TEST_PALETTE_HELPER=$test_root/palette-helper

cat >"$TEST_PALETTE_HELPER" <<'MOCK'
#!/bin/bash
set -euo pipefail
mode=$(<"$TEST_PALETTE_MODE")
case $mode in
  startup)
    printf '%s\t%s\n' yellow '#112233' green '#445566' cyan '#778899'
    ;;
  success)
    printf '%s\t%s\n' yellow '#aabbcc' green '#ddeeff' cyan '#123456'
    ;;
  slow)
    sleep 0.2
    printf '%s\t%s\n' yellow '#aabbcc' green '#ddeeff' cyan '#123456'
    ;;
  malformed)
    printf '%s\t%s\n' yellow '#aabbcc' green invalid cyan '#123456'
    ;;
  failure) exit 1 ;;
  *) exit 2 ;;
esac
MOCK
chmod 755 "$TEST_PALETTE_HELPER"
printf 'startup\n' >"$TEST_PALETTE_MODE"

timeout 8s quickshell --no-color -p "$test_root/shell.qml" 2>&1 \
  | tee "$test_root/output.log"
grep -Fq 'theme palette controller tests passed' "$test_root/output.log"
printf '[ok] theme palette controller tests passed\n'
