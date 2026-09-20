#!/bin/bash
set -euo pipefail

[[ ${1:-} == stream ]]
revision=1
refreshes=0
printf '%s\n' \
  '{"v":2,"type":"hello","build":{"version":"test"}}' \
  '{"v":2,"type":"snapshot","revision":1,"state":{"connection":{"phase":"ready","online":true,"fresh":true},"webUi":{"theme":"default","guiAssets":"/tmp/test-gui"},"folders":[],"counts":{}}}'

while IFS= read -r line; do
  id=$(jq -er '.id' <<<"$line")
  type=$(jq -er '.type' <<<"$line")
  if [[ $type == refresh ]]; then
    ((refreshes += 1, revision += 1))
    if ((refreshes == 1)); then
      printf '{"v":2,"type":"snapshot","revision":%s,"state":{"connection":{"phase":"error","online":false,"fresh":false,"error":{"message":"API unavailable"}},"folders":[],"counts":{}}}\n' "$revision"
      printf '{"v":2,"type":"result","id":"%s","ok":false,"error":{"message":"API unavailable"}}\n' "$id"
      continue
    fi
    if ((refreshes == 3)); then
      printf '{"v":2,"type":"snapshot","revision":%s,"state":{"connection":{"phase":"ready","online":true,"fresh":true},"webUi":{"theme":"default","guiAssets":"/tmp/test-gui"},"folders":[{"id":"folder","label":"Folder","path":"/tmp/folder","paused":false,"status":{"state":"idle","pullErrors":1,"needTotalItems":1,"errors":[{"path":"old","error":"blocked"}]} }],"counts":{"folders":1,"folderProblems":1,"syncingFolders":1}}}\n' "$revision"
    else
      printf '{"v":2,"type":"snapshot","revision":%s,"state":{"connection":{"phase":"ready","online":true,"fresh":true},"webUi":{"theme":"default","guiAssets":"/tmp/test-gui"},"folders":[],"counts":{}}}\n' "$revision"
    fi
  elif [[ $type == action ]] &&
      [[ $(jq -er '.action' <<<"$line") == folder.recheck-errors ]]; then
    ((revision += 1))
    printf '{"v":2,"type":"snapshot","revision":%s,"state":{"connection":{"phase":"ready","online":true,"fresh":true},"webUi":{"theme":"default","guiAssets":"/tmp/test-gui"},"folders":[{"id":"folder","label":"Folder","path":"/tmp/folder","paused":false,"status":{"state":"idle","pullErrors":0,"needTotalItems":0,"errors":[]}}],"counts":{"folders":1,"folderProblems":0,"syncingFolders":0}}}\n' "$revision"
  fi
  printf '{"v":2,"type":"result","id":"%s","ok":true}\n' "$id"
  [[ $type != shutdown ]] || exit 0
done
