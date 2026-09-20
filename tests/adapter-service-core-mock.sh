#!/bin/bash
set -euo pipefail

[[ ${1:-} == stream ]]
printf '%s\n' \
  '{"v":2,"type":"hello","build":{"version":"test"}}' \
  '{"v":2,"type":"snapshot","revision":1,"state":{"connection":{"phase":"online","healthy":true,"authorized":true,"online":true,"fresh":true},"identity":{"deviceId":"LOCAL"},"folders":[{"id":"docs","label":"Documents","path":"/tmp/long/path/docs","paused":false,"devices":[{"id":"LOCAL"},{"id":"REMOTE"}],"status":{"state":"idle","errors":[]}}],"devices":[{"id":"LOCAL","name":"Local"},{"id":"REMOTE","name":"Remote","connected":true}],"pendingFolders":{"offer":{"offeredBy":{"REMOTE":{"label":"Offered"}}}},"pendingDevices":[{"id":"PENDING","name":"Laptop"}],"nearbyDevices":[{"id":"NEARBY","addresses":["tcp://192.0.2.1:22000"]}],"activity":{},"webUi":{"url":"http://127.0.0.1:8384"},"counts":{"folders":1}}}'

while IFS= read -r line; do
  id=$(jq -er .id <<<"$line")
  type=$(jq -er .type <<<"$line")
  action=$(jq -r '.action // ""' <<<"$line")
  case $type:$action in
    configure:|refresh:)
      printf '{"v":2,"type":"result","id":"%s","ok":true}\n' "$id"
      ;;
    action:folder.rescan)
      printf '%s\n' \
        '{"v":2,"type":"snapshot","revision":2,"state":{"connection":{"phase":"online","healthy":true,"authorized":true,"online":true,"fresh":true},"identity":{"deviceId":"LOCAL"},"folders":[{"id":"docs","label":"Documents","path":"/tmp/long/path/docs","paused":false,"devices":[{"id":"LOCAL"},{"id":"REMOTE"}],"status":{"state":"scanning","errors":[]}}],"devices":[{"id":"LOCAL","name":"Local"},{"id":"REMOTE","name":"Remote","connected":true}],"pendingFolders":{"offer":{"offeredBy":{"REMOTE":{"label":"Offered"}}}},"pendingDevices":[{"id":"PENDING","name":"Laptop"}],"nearbyDevices":[{"id":"NEARBY","addresses":["tcp://192.0.2.1:22000"]}],"activity":{},"webUi":{"url":"http://127.0.0.1:8384"},"counts":{"folders":1}}}'
      printf '{"v":2,"type":"result","id":"%s","ok":true,"data":{"state":"running","targetFolderIds":["docs"],"runningFolderIds":["docs"]}}\n' "$id"
      printf '%s\n' \
        '{"v":2,"type":"snapshot","revision":3,"state":{"connection":{"phase":"online","healthy":true,"authorized":true,"online":true,"fresh":true},"identity":{"deviceId":"LOCAL"},"folders":[{"id":"docs","label":"Documents","path":"/tmp/long/path/docs","paused":false,"devices":[{"id":"LOCAL"},{"id":"REMOTE"}],"status":{"state":"idle","errors":[]}}],"devices":[{"id":"LOCAL","name":"Local"},{"id":"REMOTE","name":"Remote","connected":true}],"pendingFolders":{"offer":{"offeredBy":{"REMOTE":{"label":"Offered"}}}},"pendingDevices":[{"id":"PENDING","name":"Laptop"}],"nearbyDevices":[{"id":"NEARBY","addresses":["tcp://192.0.2.1:22000"]}],"activity":{},"webUi":{"url":"http://127.0.0.1:8384"},"counts":{"folders":1}}}'
      ;;
    action:folder.suggest-id)
      printf '{"v":2,"type":"result","id":"%s","ok":true,"data":{"folderId":"abcde-fghij"}}\n' "$id"
      ;;
    action:folder.set-sharing)
      jq -e '.args == {"folderId":"docs","deviceIds":["REMOTE"]}' \
        <<<"$line" >/dev/null
      printf '{"v":2,"type":"result","id":"%s","ok":true}\n' "$id"
      ;;
    action:device.add)
      jq -e '.args == {"deviceId":"NEARBY","deviceName":"Laptop"}' \
        <<<"$line" >/dev/null
      printf '{"v":2,"type":"result","id":"%s","ok":true}\n' "$id"
      ;;
    action:device.dismiss-pending)
      jq -e '.args == {"deviceId":"PENDING"}' <<<"$line" >/dev/null
      printf '{"v":2,"type":"result","id":"%s","ok":true}\n' "$id"
      ;;
    action:device.remove-folder-shares)
      jq -e '.args == {"deviceId":"REMOTE","folderIds":["docs"]}' \
        <<<"$line" >/dev/null
      printf '{"v":2,"type":"result","id":"%s","ok":true}\n' "$id"
      ;;
    shutdown:)
      printf '{"v":2,"type":"result","id":"%s","ok":true}\n' "$id"
      printf '%s\n' '{"v":2,"type":"end","reason":"shutdown"}'
      exit
      ;;
    *) exit 1 ;;
  esac
done
