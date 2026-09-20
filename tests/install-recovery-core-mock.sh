#!/bin/bash
set -euo pipefail

[[ ${1:-} == stream ]]
[[ -n ${SYNCSHELL_RECOVERY_MARKER:-} ]]
[[ -f $SYNCSHELL_RECOVERY_MARKER ]] || exit 23

printf '%s\n' \
  '{"v":2,"type":"hello","build":{"version":"test"}}' \
  '{"v":2,"type":"snapshot","revision":1,"state":{"connection":{"phase":"ready","online":true},"installation":{"available":false},"lifecycle":{"classification":"external","available":true,"active":false,"targetMatch":true,"canControl":false,"canStart":false},"counts":{},"folders":[]}}'

while IFS= read -r line; do
  id=$(jq -er '.id' <<<"$line")
  type=$(jq -er '.type' <<<"$line")
  printf '{"v":2,"type":"result","id":"%s","ok":true}\n' "$id"
  if [[ $type == shutdown ]]; then
    printf '%s\n' '{"v":2,"type":"end","reason":"shutdown"}'
    exit 0
  fi
done

printf '%s\n' '{"v":2,"type":"end","reason":"stdin"}'
