#!/bin/bash
set -euo pipefail

[[ ${1:-} == stream ]]
revision=1
refreshes=0
printf '%s\n' \
  '{"v":1,"type":"hello","build":{"version":"test","protocol":1}}' \
  '{"v":1,"type":"snapshot","revision":1,"state":{"connection":{"phase":"ready","online":true,"fresh":true},"webUi":{"theme":"default","guiAssets":"/tmp/test-gui"},"folders":[],"counts":{}}}'

while IFS= read -r line; do
  id=$(jq -er '.id' <<<"$line")
  type=$(jq -er '.type' <<<"$line")
  if [[ $type == refresh ]]; then
    ((refreshes += 1, revision += 1))
    if ((refreshes == 1)); then
      printf '{"v":1,"type":"snapshot","revision":%s,"state":{"connection":{"phase":"error","online":false,"fresh":false,"error":{"message":"API unavailable"}},"folders":[],"counts":{}}}\n' "$revision"
      printf '{"v":1,"type":"result","id":"%s","ok":false,"revision":%s,"error":{"message":"API unavailable"}}\n' "$id" "$revision"
      continue
    fi
    printf '{"v":1,"type":"snapshot","revision":%s,"state":{"connection":{"phase":"ready","online":true,"fresh":true},"webUi":{"theme":"default","guiAssets":"/tmp/test-gui"},"folders":[],"counts":{}}}\n' "$revision"
  fi
  printf '{"v":1,"type":"result","id":"%s","ok":true,"revision":%s}\n' "$id" "$revision"
  [[ $type != shutdown ]] || exit 0
done
