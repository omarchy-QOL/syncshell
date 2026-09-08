#!/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
output=${1:?usage: archive.sh /absolute/output.tar.gz [git-ref]}
revision=$(git -C "$root" rev-parse --verify "${2:-HEAD}^{commit}")

git -C "$root" archive --format=tar "$revision" | gzip -n >"$output"
