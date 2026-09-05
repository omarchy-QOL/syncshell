#!/bin/bash
set -euo pipefail

# shellcheck source=test_helper.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/test_helper.sh"

exists=$live/test-syncshell/dir-exists

copy_one() {
  install -d -m 755 -- "$exists"
  echo "copy video_02.bin into dir-exists"
  cp -- "$source_dir/video_02.bin" "$exists/"
  wait_counted "$wait_long"
  echo "delete video_02.bin"
  rm -- "$exists/video_02.bin"
  wait_counted "$wait_short"
  echo "copy_one done"
}

copy_two() {
  install -d -m 755 -- "$exists"
  echo "copy video_03.bin and video_04.bin into dir-exists"
  cp -- "$source_dir/video_03.bin" "$source_dir/video_04.bin" "$exists/"
  wait_counted "$wait_long"
  echo "delete video_03.bin and video_04.bin"
  rm -- "$exists/video_03.bin" "$exists/video_04.bin"
  wait_counted "$wait_short"
  echo "copy_two done"
}

main() {
  test -d "$source_dir"
  copy_one
  copy_two
}

if [[ ${1:-} == copy_one || ${1:-} == copy_two ]]; then
  "$1"
else
  main
fi
