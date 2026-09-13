#!/bin/bash
set -euo pipefail

[[ ${1:-} == stream ]]
printf '%s\n' \
  '{"v":1,"type":"hello","build":{"version":"test","protocol":1},"capabilities":[]}' \
  '{"v":1,"type":"snapshot","revision":1,"state":{"connection":{"phase":"online","healthy":true,"authorized":true,"online":true,"fresh":true},"folders":[{"id":"docs","label":"Documents","path":"/tmp/long/path/docs","paused":false,"status":{"state":"idle","errors":[]}}],"devices":[],"activity":{},"webUi":{"url":"http://127.0.0.1:8384"},"counts":{"folders":1}}}'

while IFS= read -r line; do
  id=$(jq -er .id <<<"$line")
  type=$(jq -er .type <<<"$line")
  action=$(jq -r '.action // ""' <<<"$line")
  case $type:$action in
    configure:|refresh:)
      printf '{"v":1,"type":"result","id":"%s","ok":true,"revision":1}\n' "$id"
      ;;
    action:folder.rescan)
      printf '%s\n' \
        '{"v":1,"type":"snapshot","revision":2,"state":{"connection":{"phase":"online","healthy":true,"authorized":true,"online":true,"fresh":true},"folders":[{"id":"docs","label":"Documents","path":"/tmp/long/path/docs","paused":false,"status":{"state":"scanning","errors":[]}}],"devices":[],"activity":{},"webUi":{"url":"http://127.0.0.1:8384"},"counts":{"folders":1}}}'
      printf '{"v":1,"type":"result","id":"%s","ok":true,"revision":2}\n' "$id"
      printf '%s\n' \
        '{"v":1,"type":"snapshot","revision":3,"state":{"connection":{"phase":"online","healthy":true,"authorized":true,"online":true,"fresh":true},"folders":[{"id":"docs","label":"Documents","path":"/tmp/long/path/docs","paused":false,"status":{"state":"idle","errors":[]}}],"devices":[],"activity":{},"webUi":{"url":"http://127.0.0.1:8384"},"counts":{"folders":1}}}'
      ;;
    action:folder.suggest-id)
      printf '{"v":1,"type":"result","id":"%s","ok":true,"revision":3,"data":{"folderId":"abcde-fghij"}}\n' "$id"
      ;;
    shutdown:)
      printf '{"v":1,"type":"result","id":"%s","ok":true,"revision":3}\n' "$id"
      printf '%s\n' '{"v":1,"type":"end","reason":"shutdown"}'
      exit
      ;;
    *) exit 1 ;;
  esac
done
