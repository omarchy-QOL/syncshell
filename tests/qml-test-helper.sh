#!/bin/bash

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d "/tmp/syncshell-$(basename -- "${BASH_SOURCE[1]}" .sh).XXXXXX")
trap 'find "$test_root" -depth -delete' EXIT

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
