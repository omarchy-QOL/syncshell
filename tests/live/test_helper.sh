wait_short=30
wait_middle=60
wait_long=120
live=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_dir=$HOME/Work/syncthing-testing

wait_counted() {
  local secs=$1
  local i
  for ((i = 1; i <= secs; i++)); do
    printf '\rwait %ss  (%s/%s)' "$secs" "$i" "$secs"
    sleep 1
  done
  printf '\n'
}
