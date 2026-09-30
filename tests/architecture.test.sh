#!/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
stage=$(mktemp -d /tmp/syncshell-validation.XXXXXX)
trap 'rm -rf -- "$stage"' EXIT

# Validate the installable tree, not ignored editor/test dependencies.
(
  cd -- "$root"
  git ls-files --cached --others --exclude-standard --deduplicate -z \
    | while IFS= read -r -d '' file; do
        if [[ -e $file || -L $file ]]; then
          printf '%s\0' "$file"
        fi
      done \
    | tar --null -T - -cf -
) | tar -C "$stage" -xf -
omarchy plugin validate "$stage"
