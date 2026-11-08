#!/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
required_go=$(awk '$1 == "go" { print "go" $2 }' "$root/core/go.mod")
[[ $(go env GOVERSION) == "$required_go" ]] || {
  printf 'bundled core requires %s\n' "$required_go" >&2
  exit 1
}

# Pin the instruction-set baselines instead of inheriting Go's defaults: v1
# runs on every x86_64 machine, including old Intel Macs, and v8.0 on every
# aarch64 one, from Raspberry Pis to Apple Silicon Macs and Snapdragon laptops.
build_core() {
  local directory=$1 goarch=$2 baseline=$3
  local output="$root/bin/$directory/syncshell-core"

  mkdir -p -- "$(dirname -- "$output")"
  (
    cd -- "$root/core"
    env GOOS=linux GOARCH="$goarch" "$baseline" CGO_ENABLED=0 \
      go build -mod=readonly -trimpath -buildvcs=false \
        -ldflags='-buildid=' -o "$output" ./cmd/syncshell-core
  )
  chmod 755 -- "$output"
}

build_core x86_64 amd64 GOAMD64=v1
build_core aarch64 arm64 GOARM64=v8.0
chmod 755 -- "$root/bin/syncshell-core"
(
  cd -- "$root"
  sha256sum bin/syncshell-core bin/x86_64/syncshell-core \
    bin/aarch64/syncshell-core >packaging/bundled/SHA256SUMS
)
