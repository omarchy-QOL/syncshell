#!/bin/bash
set -euo pipefail

bundle=$(cd -- "$(dirname -- "$0")" && pwd)
assets=${1:?usage: bash install.sh /absolute/gui-override-directory}

require_absolute_assets() {
	[[ $assets == /* ]] || {
		printf 'Use an absolute GUI override directory\n' >&2
		exit 1
	}
}

require_replaceable_target() {
	[[ ! -L $target && (! -e $target || -d $target) ]] || exit 1
}

require_absolute_assets
(cd -- "$bundle" && sha256sum --quiet --check SHA256SUMS)
mkdir -p -- "$assets"
target="$assets/syncshell-modern"
require_replaceable_target
staging=$(mktemp -d -- "$assets/.syncshell-modern.XXXXXX")
previous="$staging.previous"

rollback_install() {
	# A failed final rename must restore the previous complete installation.
	if [[ -d $previous && ! -e $target ]]; then mv -- "$previous" "$target"; fi
}

cleanup_staging() {
	[[ ! -d $staging ]] || rm -rf -- "$staging"
	[[ ! -d $previous ]] || rm -rf -- "$previous"
}

cleanup() {
	rollback_install
	cleanup_staging
}

trap cleanup EXIT
cp -a -- "$bundle/gui/syncshell-modern/." "$staging/"
if [[ -d $target ]]; then mv -- "$target" "$previous"; fi
mv -- "$staging" "$target"
printf 'Installed %s\n' "$target"
printf 'After first installation, restart Syncthing and select syncshell-modern.\n'
