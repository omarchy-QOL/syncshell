#!/bin/bash
set -euo pipefail

# shellcheck source=test_helper.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/test_helper.sh"

new_dir=$live/dir-non-existent

test -d "$source_dir"
rm -rf -- "$new_dir"
install -d -m 755 -- "$new_dir"
echo "copy three bins into dir-non-existent"
cp -- \
  "$source_dir/video_02.bin" \
  "$source_dir/video_03.bin" \
  "$source_dir/video_04.bin" \
  "$new_dir/"
wait_counted "$wait_long"
echo "delete dir-non-existent"
rm -rf -- "$new_dir"
wait_counted "$wait_middle"
echo "copy-new-dir done"
