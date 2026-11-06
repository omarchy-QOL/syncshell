#!/bin/bash
set -euo pipefail

[[ ${1:-} == stream ]]
shift
exit_on_request=false
exclusive_lock=
for argument in "$@"; do
  [[ $argument != --test-exit-on-request ]] || exit_on_request=true
  [[ $argument != --test-exclusive-lock=* ]] || exclusive_lock=${argument#*=}
done

if [[ -n $exclusive_lock ]]; then
  exec 9>"$exclusive_lock"
  flock -n 9 || exit 88
  trap 'sleep 0.2; exit 0' TERM
fi

printf '%s\n' \
  '{"v":2,"type":"hello","build":{"version":"test"}}' \
  '{"v":2,"type":"snapshot","revision":1,"state":{"connection":{"online":true},"identity":{"deviceId":"TEST-ID"},"folders":[{"id":"folder"}]}}'

while IFS= read -r line; do
  id=$(jq -er '.id' <<<"$line")
  type=$(jq -er '.type' <<<"$line")
  case $type in
    configure|refresh|action)
      [[ $exit_on_request == false ]] || exit 17
      printf '{"v":2,"type":"result","id":"%s","ok":true}\n' "$id"
      ;;
    shutdown)
      printf '{"v":2,"type":"result","id":"%s","ok":true}\n' "$id"
      printf '%s\n' '{"v":2,"type":"end","reason":"shutdown"}'
      exit 0
      ;;
    *) exit 1 ;;
  esac
done

printf '%s\n' '{"v":2,"type":"end","reason":"stdin"}'
