#!/bin/bash
set -euo pipefail

integration_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$integration_root/../.." && pwd)
target=${1:-}

[[ -n $target && $target == /* ]] || {
  printf 'usage: %s EMPTY_ABSOLUTE_DIRECTORY\n' "$0" >&2
  exit 2
}
mkdir -p -- "$target"
[[ -z $(find "$target" -mindepth 1 -maxdepth 1 -print -quit) ]] || {
  printf 'DMS target must be empty\n' >&2
  exit 1
}

(cd -- "$repo_root" && \
  sha256sum --check packaging/bundled/SHA256SUMS >/dev/null)
(cd -- "$repo_root/webui" && sha256sum --quiet --check SHA256SUMS)

while IFS= read -r path; do
  [[ $path != /* && $path != *..* && -f $repo_root/$path ]] || {
    printf 'invalid package source: %s\n' "$path" >&2
    exit 1
  }
  install -Dm0644 -- "$repo_root/$path" "$target/$path"
done <"$integration_root/qml-files.txt"
node "$repo_root/integrations/assemble-qml.mjs" "$target" \
  "$integration_root/qml-files.txt" "$integration_root/import-map.json"

install -d -- "$target/bin/x86_64" "$target/bin/aarch64" \
  "$target/assets/mono" "$target/packaging/bundled"
install -m 0644 -- "$integration_root/plugin.json" "$target/plugin.json"
install -m 0644 -- "$repo_root/hosts/dankmaterialshell/README.md" "$target/README.md"
install -m 0644 -- "$repo_root/LICENSE" "$repo_root/CHANGELOG.md" "$target/"
install -m 0644 -- "$repo_root/packaging/bundled/LICENSE.golang" \
  "$repo_root/packaging/bundled/SHA256SUMS" "$target/packaging/bundled/"
for icon in status-default.svg status-notify.svg status-pause.svg status-sync.svg; do
  install -m 0644 -- "$repo_root/assets/$icon" "$target/assets/$icon"
  install -m 0644 -- "$repo_root/assets/mono/$icon" "$target/assets/mono/$icon"
done
install -m 0644 -- "$repo_root/assets/LICENSE.md" "$target/assets/LICENSE.md"
cp -a -- "$repo_root/webui" "$target/webui"
install -m 0755 -- "$repo_root/bin/syncshell-core" \
  "$target/bin/syncshell-core"
install -m 0755 -- "$repo_root/bin/x86_64/syncshell-core" \
  "$target/bin/x86_64/syncshell-core"
install -m 0755 -- "$repo_root/bin/aarch64/syncshell-core" \
  "$target/bin/aarch64/syncshell-core"
node - "$repo_root" "$target" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const [source, output] = process.argv.slice(2);
const recipe = crypto.createHash("sha256");
for (const file of ["integrations/dankmaterialshell/assemble.sh",
  "integrations/dankmaterialshell/qml-files.txt", "integrations/dankmaterialshell/import-map.json",
  "integrations/assemble-qml.mjs"])
  recipe.update(file + "\n").update(fs.readFileSync(path.join(source, file)));
const provenance = {
  format: 1,
  repository: "https://github.com/omarchy-QOL/syncshell",
  version: JSON.parse(fs.readFileSync(path.join(output, "plugin.json"))).version,
  dmsSDK: "2.0.0",
  coreToolchain: "go" + fs.readFileSync(path.join(source, "core/go.mod"), "utf8").match(/^go (.+)$/m)[1],
  recipeSha256: recipe.digest("hex"),
  webUi: JSON.parse(fs.readFileSync(path.join(output, "webui/manifest.json")))
};
fs.writeFileSync(path.join(output, "ASSEMBLY.json"), JSON.stringify(provenance, null, 2) + "\n");
NODE
(
  cd -- "$target"
  find . -type f ! -name PACKAGE-SHA256SUMS -print0 \
    | LC_ALL=C sort -z | xargs -0 sha256sum >PACKAGE-SHA256SUMS
)
printf '[ok] assembled DMS adapter\n'
