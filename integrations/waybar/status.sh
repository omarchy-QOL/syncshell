#!/bin/bash
set -euo pipefail

runtime_dir=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
status_file="$runtime_dir/syncshell-waybar-status.json"
fallback='{"text":"ST ...","tooltip":"Syncshell is starting","class":"starting","alt":"starting"}'
previous=

while :; do
  if [[ -s $status_file ]]; then
    current=$(<"$status_file") || current=$fallback
  else
    current=$fallback
  fi
  if [[ $current != "$previous" ]]; then
    printf '%s\n' "$current"
    previous=$current
  fi
  sleep 0.5
done
