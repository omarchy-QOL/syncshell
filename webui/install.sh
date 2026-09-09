#!/bin/bash
set -euo pipefail

bundle=$(cd -- "$(dirname -- "$0")" && pwd)
assets=${1:?usage: bash install.sh /absolute/gui-override-directory}
[[ $assets == /* ]] || { printf 'Use an absolute GUI override directory\n' >&2; exit 1; }
(cd -- "$bundle" && sha256sum --quiet --check SHA256SUMS)
mkdir -p -- "$assets"
target="$assets/syncshell-modern"
[[ ! -L $target && ( ! -e $target || -d $target ) ]] || exit 1
staging=$(mktemp -d -- "$assets/.syncshell-modern.XXXXXX")
previous="$staging.previous"
cleanup() {
  if [[ -d $previous && ! -e $target ]]; then mv -- "$previous" "$target"; fi
  [[ ! -d $staging ]] || rm -rf -- "$staging"
  [[ ! -d $previous ]] || rm -rf -- "$previous"
}
trap cleanup EXIT
cp -a -- "$bundle/gui/syncshell-modern/." "$staging/"
if [[ -d $target ]]; then mv -- "$target" "$previous"; fi
mv -- "$staging" "$target"
printf 'Installed %s\n' "$target"
printf 'After first installation, restart Syncthing and select syncshell-modern.\n'
