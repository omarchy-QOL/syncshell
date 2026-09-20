#!/bin/bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
state_root=${XDG_STATE_HOME:-$HOME/.local/state}/syncshell
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT

shell_name=
while [[ $# -gt 0 ]]; do
  case $1 in
    --shell)
      [[ $# -ge 2 ]] || {
        printf 'usage: %s --shell dms|ii|caelestia|waybar\n' "$0" >&2
        exit 2
      }
      shell_name=$2
      shift 2
      ;;
    *)
      printf 'unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

case $shell_name in
  dms|ii|caelestia|waybar) ;;
  *)
    printf 'usage: %s --shell dms|ii|caelestia|waybar\n' "$0" >&2
    exit 2
    ;;
esac

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing required command: %s\n' "$1" >&2
    exit 1
  }
}

clone_pinned() {
  local url=$1 commit=$2 target=$3

  git init -q "$target"
  git -C "$target" remote add origin "$url"
  git -C "$target" fetch -q --depth=1 origin "$commit"
  git -C "$target" checkout -q --detach FETCH_HEAD
  [[ $(git -C "$target" rev-parse HEAD) == "$commit" ]]
}

restart_vm_shell() {
  if systemctl --user is-active syncshell-shell.service >/dev/null 2>&1; then
    systemctl --user restart syncshell-shell.service
  fi
}

wait_dms() {
  local deadline=$((SECONDS + 120))

  while (( SECONDS < deadline )); do
    dms ipc call plugins list >/dev/null 2>&1 && return
    sleep 1
  done
  printf 'DMS IPC did not become ready\n' >&2
  return 1
}

wait_dms_plugin() {
  local status deadline=$((SECONDS + 120))

  while (( SECONDS < deadline )); do
    status=$(dms ipc call plugins status syncshell 2>/dev/null || true)
    if [[ $status == loaded ]] \
        && dms ipc call widget list 2>/dev/null \
          | grep -q '^syncshell\([[:space:]]\|$\)'; then
      return
    fi
    sleep 0.25
  done
  printf 'DMS Syncshell plugin did not become ready\n' >&2
  return 1
}

configure_dms_widget() {
  local settings="$HOME/.config/DankMaterialShell/settings.json"
  local position result temporary

  if [[ ! -s $settings ]]; then
    position=$(dms ipc call bar getPosition id default)
    case $position in
      top|bottom|left|right) ;;
      *) printf 'DMS bar position is unavailable: %s\n' "$position" >&2; return 1 ;;
    esac
    result=$(dms ipc call bar setPosition id default "$position")
    [[ $result == BAR_POSITION_SET_SUCCESS ]]
    for _ in {1..50}; do
      [[ -s $settings ]] && break
      sleep 0.1
    done
  fi
  [[ -s $settings ]]
  temporary=$(mktemp "$HOME/.config/DankMaterialShell/.settings.XXXXXX")
  jq '
    .barConfigs = ((.barConfigs // []) | map(
      if .id == "default" then
        .rightWidgets = (((.rightWidgets // []) + ["syncshell"]) | unique)
      else . end))
  ' "$settings" >"$temporary"
  chmod --reference="$settings" "$temporary"
  mv -- "$temporary" "$settings"
}

install_dms() {
  local assembled="$work/Syncshell"
  local target="$HOME/.config/DankMaterialShell/plugins/Syncshell"
  local backup

  for command_name in dms jq; do
    require_command "$command_name"
  done
  bash "$repo_root/integrations/dankmaterialshell/assemble.sh" "$assembled"
  mkdir -p -- "$(dirname -- "$target")" "$state_root/backups"
  if [[ -e $target ]]; then
    backup="$state_root/backups/dms-$(date -u +%Y%m%dT%H%M%SZ)"
    mv -- "$target" "$backup"
  fi
  mv -- "$assembled" "$target"
  wait_dms
  dms ipc call plugin-scan scan >/dev/null
  for _ in {1..480}; do
    status=$(dms ipc call plugins status syncshell 2>/dev/null || true)
    [[ -n $status && $status != ERROR:* && $status != PLUGIN_NOT_FOUND:* \
      && $status != 'Target not found.' ]] && break
    sleep 0.25
  done
  status=$(dms ipc call plugins enable syncshell)
  [[ $status == *PLUGIN_ENABLE_SUCCESS* ]]
  configure_dms_widget
  systemctl --user restart dms.service
  wait_dms
  wait_dms_plugin
}

install_ii() {
  local checkout="$work/illogical-impulse"
  local source_config target_config backup relative
  readonly ii_commit=42d0aae17b744a38cd05c9044c189bfc9b13869a

  require_command git
  require_command patch
  target_config="$HOME/.config/quickshell/ii"
  [[ -d $target_config ]] || {
    printf 'Illogical Impulse config is missing: %s\n' "$target_config" >&2
    exit 1
  }
  clone_pinned https://github.com/end-4/dots-hyprland.git \
    "$ii_commit" "$checkout"
  bash "$repo_root/integrations/illogical-impulse/apply.sh" "$checkout"
  source_config="$checkout/dots/.config/quickshell/ii"
  backup="$state_root/backups/ii-$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p -- "$backup" "$target_config/services" \
    "$target_config/modules/ii/bar"
  for relative in services/Syncshell.qml \
      modules/ii/bar/SyncshellIndicator.qml \
      modules/ii/bar/SyncshellPopup.qml \
      modules/ii/bar/BarContent.qml; do
    [[ ! -e $target_config/$relative ]] \
      || cp -a --parents -- "$target_config/$relative" "$backup/"
    install -m 0644 -- "$source_config/$relative" \
      "$target_config/$relative"
  done
  [[ ! -e $target_config/syncshell ]] \
    || mv -- "$target_config/syncshell" "$backup/syncshell"
  cp -a -- "$source_config/syncshell" "$target_config/syncshell"
  restart_vm_shell
}

install_caelestia() {
  local checkout="$work/caelestia"
  readonly caelestia_commit=1d0e5a588c61f1d905eba5fe8446ec222d37f50c

  for command_name in cmake git ninja patch; do
    require_command "$command_name"
  done
  clone_pinned https://github.com/caelestia-dots/shell.git \
    "$caelestia_commit" "$checkout"
  bash "$repo_root/integrations/caelestia/apply.sh" "$checkout"
  cmake -S "$checkout" -B "$checkout/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ -DVERSION=2.3.0 \
    -DGIT_REVISION="$caelestia_commit" \
    -DINSTALL_QSCONFDIR="$HOME/.config/quickshell/caelestia"
  cmake --build "$checkout/build"
  sudo cmake --install "$checkout/build"
  sudo chown -R "$(id -u):$(id -g)" \
    "$HOME/.config/quickshell/caelestia"
  restart_vm_shell
}

install_waybar() {
  local bundle="$work/waybar"

  require_command quickshell
  require_command waybar
  bash "$repo_root/integrations/waybar/assemble.sh" "$bundle"
  bash "$bundle/install.sh"
  restart_vm_shell
}

(cd -- "$repo_root" && \
  sha256sum --check packaging/bundled/SHA256SUMS >/dev/null)
"install_$shell_name"
printf '[ok] installed Syncshell for %s\n' "$shell_name"
