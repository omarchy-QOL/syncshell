#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
target=${1:-"$root/dist/caelestia"}
[[ $target == /* ]] || { printf 'target must be absolute\n' >&2; exit 2; }
mkdir -p -- "$target"
[[ -z $(find "$target" -mindepth 1 -maxdepth 1 -print -quit) ]] || {
  printf 'target must be empty\n' >&2; exit 1;
}
(cd -- "$root" && sha256sum --check packaging/bundled/SHA256SUMS >/dev/null)
while IFS= read -r file; do
  install -Dm644 -- "$root/$file" "$target/$file"
done < "$root/integrations/caelestia/qml-files.txt"
node "$root/integrations/assemble-qml.mjs" "$target" \
  "$root/integrations/caelestia/qml-files.txt" \
  "$root/integrations/caelestia/import-map.json"
install -Dm644 -- "$root/integrations/caelestia/manifest.json" "$target/manifest.json"
for file in syncshell-core x86_64/syncshell-core aarch64/syncshell-core; do
  install -Dm755 -- "$root/bin/$file" "$target/bin/$file"
done
cp -a -- "$root/webui" "$target/webui"
install -Dm644 -- "$root/assets/status-default.svg" "$target/assets/status-default.svg"
install -Dm644 -- "$root/assets/LICENSE.md" "$target/assets/LICENSE.md"
install -m644 -- "$root/LICENSE" "$root/CHANGELOG.md" "$target/"
install -m644 -- "$root/hosts/caelestia/README.md" "$target/README.md"
printf '%s\n' 'caelestia-shell 4e288c54a3b039154d19fe8a2064a174eb634405' \
  "syncshell-base $(git -C "$root" rev-parse HEAD)" > "$target/PROVENANCE"
(cd -- "$target" && find . -type f ! -name SHA256SUMS -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS)
printf '[ok] assembled Caelestia plugin at %s\n' "$target"
