#!/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
required_go=$(awk '$1 == "go" { print "go" $2 }' "$root/core/go.mod")
[[ $(go env GOVERSION) == "$required_go" ]] || {
  printf 'bundled core requires %s\n' "$required_go" >&2
  exit 1
}

build_core() {
  local directory=$1 goarch=$2
  local output="$root/bin/$directory/syncshell-core"

  mkdir -p -- "$(dirname -- "$output")"
  (
    cd -- "$root/core"
    GOOS=linux GOARCH="$goarch" CGO_ENABLED=0 \
      go build -mod=readonly -trimpath -buildvcs=false \
        -ldflags='-buildid=' -o "$output" ./cmd/syncshell-core
  )
  chmod 755 -- "$output"
}

build_core x86_64 amd64
build_core aarch64 arm64
chmod 755 -- "$root/bin/syncshell-core"
(
  cd -- "$root"
  sha256sum bin/syncshell-core bin/x86_64/syncshell-core \
    bin/aarch64/syncshell-core >packaging/bundled/SHA256SUMS
)
