#!/bin/bash
set -euo pipefail

temporary=""
expected=""

cleanup() {
  [[ -z $temporary ]] || rm -f -- "$temporary"
  [[ -z $expected ]] || rm -f -- "$expected"
}

trap cleanup EXIT

usage() {
  printf '%s\n' \
    'Usage: syncthing-settings.sh ensure <template> <target> <branded|themed>' \
    '       syncthing-settings.sh replace <target>  # validated JSON on stdin' \
    '       syncthing-settings.sh migrate <target>  # validated JSON on stdin' \
    '       syncthing-settings.sh compare <template> <target>' \
    >&2
  exit 2
}

seed_settings() {
  local template=$1 target=$2 icon_style=$3
  local target_dir

  [[ -f $template ]] || {
    printf 'Settings template is missing: %s\n' "$template" >&2
    return 1
  }
  [[ $icon_style == "branded" || $icon_style == "themed" ]] || usage
  [[ ! -L $target || -e $target ]] || {
    printf 'Settings link has no target\n' >&2
    return 1
  }
  [[ ! -e $target ]] || return 0

  target_dir=$(dirname -- "$target")
  if [[ ! -d $target_dir ]]; then
    mkdir -p -- "$target_dir"
    chmod 700 -- "$target_dir"
  fi

  temporary=$(mktemp --tmpdir="$target_dir" .settings.toml.XXXXXX)
  sed -E "s/^(icon_style[[:space:]]*=[[:space:]]*)\"(branded|themed)\"/\1\"$icon_style\"/" \
    "$template" >"$temporary"
  chmod 600 -- "$temporary"
  mv -- "$temporary" "$target"
  temporary=""
}

capture_target() {
  original_path=$1
  resolved_path=$(realpath -e -- "$original_path")
  target_dir=$(dirname -- "$resolved_path")
  expected=$(mktemp --tmpdir="$target_dir" .settings-original.XXXXXX)
  temporary=$(mktemp --tmpdir="$target_dir" .settings.toml.XXXXXX)
  cp -- "$resolved_path" "$expected"
}

check_target() {
  if [[ $(realpath -e -- "$original_path") != "$resolved_path" ]] \
      || ! cmp -s -- "$expected" "$resolved_path"; then
    printf 'Settings changed since the preview; review the file again\n' >&2
    exit 3
  fi
}

commit_target() {
  check_target
  chmod --reference="$resolved_path" "$temporary"
  mv -- "$temporary" "$resolved_path"
  temporary=""
}

# The panel computes the whole new file; this only commits it if the file
# still holds what the panel read.
read_request() {
  local request
  IFS= read -r request
  jq -e '(.original | type) == "string" and (.replacement | type) == "string"' \
    <<<"$request" >/dev/null
  capture_target "$1"
  jq -j '.original' <<<"$request" >"$expected"
  jq -j '.replacement' <<<"$request" >"$temporary"
}

migrate_settings() {
  local backup
  read_request "$1"
  check_target
  backup=$(mktemp -- "$resolved_path.before-port.XXXXXX")
  cp -p -- "$resolved_path" "$backup"
  commit_target
  printf '%s\n' "$backup"
}

compare_settings() {
  local template=$1 target=$2 reference_dir reference
  reference_dir=${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}
  reference=$(mktemp -- "$reference_dir/syncshell-settings-reference.XXXXXX.toml")
  cp -- "$template" "$reference"
  omarchy launch editor "$target" "$reference" >/dev/null
  printf '%s\n' "$reference"
}

case "${1:-}" in
  ensure)
    [[ $# == 4 ]] || usage
    seed_settings "$2" "$3" "$4"
    target=$3
    ;;
  replace)
    [[ $# == 2 ]] || usage
    read_request "$2"
    commit_target
    target=$2
    ;;
  migrate)
    [[ $# == 2 ]] || usage
    migrate_settings "$2"
    exit
    ;;
  compare)
    [[ $# == 3 ]] || usage
    compare_settings "$2" "$3"
    exit
    ;;
  *) usage ;;
esac

printf '%s\n' "$target"
