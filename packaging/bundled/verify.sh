#!/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
launcher=bin/syncshell-core
test_root=$(mktemp -d /tmp/syncshell-bundled-verify.XXXXXX)
trap 'find "$test_root" -depth -delete' EXIT

fail() {
  printf 'bundled core verification failed: %s\n' "$*" >&2
  exit 1
}

verify_mode() {
  local relative=$1
  [[ $(git -C "$root" ls-files -s -- "$relative" | awk '{print $1}') == 100755 ]] \
    || fail "$relative Git mode is not 100755"
}

verify_binary() {
  local relative=$1 file_arch=$2 goarch=$3
  local binary="$root/$relative" metadata build_metadata

  [[ -f $binary && ! -L $binary && -x $binary ]] \
    || fail "$relative is not a regular executable"
  verify_mode "$relative"
  metadata=$(file -- "$binary")
  [[ $metadata == *"ELF 64-bit LSB executable, $file_arch"* ]] \
    || fail "$relative architecture is unexpected"
  [[ $metadata == *"statically linked"* ]] \
    || fail "$relative is dynamically linked"
  build_metadata=$(go version -m "$binary")
  grep -Fq $'path\tgithub.com/omarchy-QOL/syncshell/core/cmd/syncshell-core' \
    <<<"$build_metadata" || fail "$relative Go module path is unexpected"
  grep -Fq $'build\tGOARCH='"$goarch" <<<"$build_metadata" \
    || fail "$relative Go architecture metadata is unexpected"
  grep -Fq $'build\tGOOS=linux' <<<"$build_metadata" \
    || fail "$relative Go operating-system metadata is unexpected"
  if strings -- "$binary" \
      | rg -n '/home/iz|/home-hdd-cold|BEGIN (RSA |OPENSSH )?PRIVATE KEY' \
        >/dev/null; then
    fail "$relative contains a secret marker or developer path"
  fi
  printf '%s\n%s\n' "$metadata" "$build_metadata"
}

[[ -f $root/$launcher && ! -L $root/$launcher && -x $root/$launcher ]] \
  || fail "launcher is not a regular executable"
verify_mode "$launcher"
bash -n "$root/$launcher"
(
  cd -- "$root"
  sha256sum --check packaging/bundled/SHA256SUMS
)
verify_binary bin/x86_64/syncshell-core x86-64 amd64
verify_binary bin/aarch64/syncshell-core "ARM aarch64" arm64

config="$test_root/config.xml"
printf '%s\n' \
  '<configuration>' \
  '  <gui tls="false">' \
  '    <address>127.0.0.1:1</address>' \
  '    <apikey>verification-placeholder</apikey>' \
  '  </gui>' \
  '</configuration>' >"$config"
chmod 600 -- "$config"
frames=$("$root/$launcher" stream --config "$config" \
  </dev/null 2>/dev/null || true)
hello=$(sed -n '1p' <<<"$frames")
jq -e --arg version "$(jq -er .version "$root/manifest.json")" \
  '.v == 2 and .type == "hello" and .build.version == $version' \
  <<<"$hello" >/dev/null \
  || fail "runtime version or protocol is unexpected"
