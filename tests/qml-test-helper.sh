#!/bin/bash

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d "/tmp/syncshell-$(basename -- "${BASH_SOURCE[1]}" .sh).XXXXXX")
trap 'find "$test_root" -depth -delete' EXIT

configure_visual_test() {
  local pause_ms=0
  if (( $# )); then
    if [[ $# != 2 ]] || [[ $1 != --pause-ms ]] \
        || [[ ! $2 =~ ^(0|[1-9][0-9]{0,4})$ ]] || (( $2 > 60000 )); then
      printf 'usage: bash %s [--pause-ms 0..60000]\n' "${BASH_SOURCE[1]}" >&2
      return 2
    fi
    pause_ms=$2
  fi
  export SYNCSHELL_TEST_PAUSE_MS=$pause_ms
  # Leave room for up to 30 viewing checkpoints without weakening fast runs.
  # shellcheck disable=SC2034
  visual_test_timeout=$((10 + (30 * pause_ms + 999) / 1000))s
}

stage_qml_test() {
  # Keep imported components inside Quickshell's configuration root.
  mkdir -p -- "$test_root/tests" "$test_root/bin/x86_64"
  cp -- "$root/tests/$1.qml" "$test_root/tests/TestScenario.qml"
  shift
  (cd -- "$root" && cp -a --parents -- "$@" "$test_root")
  printf 'import "tests"\nTestScenario {}\n' >"$test_root/shell.qml"
}

stage_omarchy_test() {
  stage_qml_test "$@"
  ln -s -- /usr/share/omarchy/shell/Commons "$test_root/Commons"
  ln -s -- /usr/share/omarchy/shell/Ui "$test_root/Ui"
}
