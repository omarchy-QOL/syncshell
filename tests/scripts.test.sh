#!/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d /tmp/syncthing-plugin-tests.XXXXXX)
trap 'find "$test_root" -depth -delete' EXIT

fail() {
  printf 'scripts.test.sh: %s\n' "$*" >&2
  exit 1
}

test_settings() {
  local target="$test_root/settings/config/settings.toml"
  bash "$root/hosts/omarchy/scripts/syncthing-settings.sh" ensure \
    "$root/hosts/omarchy/config/settings.toml" "$target" themed >/dev/null
  grep -q '^version = 2$' "$target" \
    || fail "settings version was not seeded"
  grep -q '^\[style\]$' "$target" \
    || fail "style section was not seeded"
  grep -Eq '^icon_style[[:space:]]*=[[:space:]]*"themed"' "$target" \
    || fail "legacy icon choice was not seeded"
  grep -Eq '^service_state[[:space:]]*=[[:space:]]*"enabled"' "$target" \
    || fail "service state was not seeded"
  grep -Eq '^probe_interval_seconds[[:space:]]*=[[:space:]]*15$' "$target" \
    || fail "service probe interval was not seeded"

  printf '%s\n' '' '# retained owner comment' '[future]' \
    'retained_value = "untouched"' >>"$target"

  bash "$root/hosts/omarchy/scripts/syncthing-settings.sh" set-service-state \
    "$root/hosts/omarchy/config/settings.toml" "$target" themed disabled \
    >/dev/null
  grep -Eq '^service_state[[:space:]]*=[[:space:]]*"disabled"' "$target" \
    || fail "service state was not updated"
  [[ $(grep -c '^service_state[[:space:]]*=' "$target") == 1 ]] \
    || fail "service state update created a duplicate"
  grep -Eq '^icon_style[[:space:]]*=[[:space:]]*"themed"' "$target" \
    || fail "service state update changed icon style"
  grep -Fxq '# retained owner comment' "$target" \
    || fail "service state update removed an owner comment"
  grep -Fxq 'retained_value = "untouched"' "$target" \
    || fail "service state update removed an additive field"

  local legacy="$test_root/settings/config/legacy.toml"
  printf '%s\n' \
    'icon_style = "branded"' \
    'web_ui_theme = "default"' \
    >"$legacy"
  bash "$root/hosts/omarchy/scripts/syncthing-settings.sh" set-service-state \
    "$root/hosts/omarchy/config/settings.toml" "$legacy" branded disabled \
    >/dev/null
  grep -Fxq '[service]' "$legacy" \
    || fail "legacy settings did not receive a service section"
  grep -Eq '^service_state[[:space:]]*=[[:space:]]*"disabled"' "$legacy" \
    || fail "legacy settings did not receive the service state"
  grep -Fxq 'web_ui_theme = "default"' "$legacy" \
    || fail "legacy settings were not preserved"

  local invalid="$test_root/settings/config/invalid.toml"
  local invalid_before
  printf '%s\n' \
    'icon_style = "branded"' \
    'web_ui_theme = "default"' \
    '[service]' \
    'service_state = "enabled"' \
    'service_state = "disabled"' \
    >"$invalid"
  invalid_before=$(<"$invalid")
  if bash "$root/hosts/omarchy/scripts/syncthing-settings.sh" \
      set-service-state "$root/hosts/omarchy/config/settings.toml" \
      "$invalid" branded enabled \
      >/dev/null 2>&1; then
    fail "invalid service settings update succeeded"
  fi
  [[ $(<"$invalid") == "$invalid_before" ]] \
    || fail "failed service settings update changed the file"

  printf '%s\n' '# user-owned' >"$target"
  bash "$root/hosts/omarchy/scripts/syncthing-settings.sh" ensure \
    "$root/hosts/omarchy/config/settings.toml" "$target" branded >/dev/null
  [[ $(<"$target") == "# user-owned" ]] \
    || fail "existing settings were overwritten"
}

test_installation_status() {
  local sandbox="$test_root/installation-status"
  local fake_bin="$sandbox/bin"
  local output
  mkdir -p -- "$fake_bin" "$sandbox/home" "$sandbox/runtime"
  printf '%s\n' '#!/bin/bash' 'exit 0' >"$fake_bin/syncthing"
  printf '%s\n' \
    '#!/bin/bash' \
    'set -euo pipefail' \
    'case " $* " in' \
    '  *" --property=LoadState "*) printf '\''loaded\n'\'' ;;' \
    '  *" --property=ActiveState "*) printf '\''inactive\n'\'' ;;' \
    '  *" --property=UnitFileState "*) printf '\''disabled\n'\'' ;;' \
    '  *) exit 1 ;;' \
    'esac' \
    >"$fake_bin/systemctl"
  chmod 700 -- "$fake_bin/syncthing" "$fake_bin/systemctl"

  output=$(HOME="$sandbox/home" \
    XDG_RUNTIME_DIR="$sandbox/runtime" \
    PATH="$fake_bin:$PATH" \
    bash "$root/hosts/omarchy/scripts/syncthing-install.sh" status)
  jq -e '
    .state == "existing"
    and .executable != ""
    and (.operationRunning | type) == "boolean"
  ' <<<"$output" >/dev/null \
    || fail "installation status omitted systemd service state"

  # Isolate PATH so a host package cannot hide the Flatpak fallback.
  local tool
  for tool in bash readlink jq timeout; do
    ln -s -- "$(command -v "$tool")" "$fake_bin/$tool"
  done
  printf '%s\n' '#!/bin/bash' \
    '[[ $* == "info com.github.zocker_160.SyncThingy" ]]' \
    >"$fake_bin/flatpak"
  chmod 700 -- "$fake_bin/flatpak"
  rm -- "$fake_bin/syncthing"
  output=$(HOME="$sandbox/home" XDG_RUNTIME_DIR="$sandbox/runtime" \
    PATH="$fake_bin" bash "$root/hosts/omarchy/scripts/syncthing-install.sh" status)
  jq -e '.state == "existing" and .executable == "com.github.zocker_160.SyncThingy (Flatpak)"' \
    <<<"$output" >/dev/null || fail "SyncThingy-only installation was not detected"

  printf '%s\n' '#!/bin/bash' 'exit 1' >"$fake_bin/flatpak"
  output=$(HOME="$sandbox/home" XDG_RUNTIME_DIR="$sandbox/runtime" \
    PATH="$fake_bin" bash "$root/hosts/omarchy/scripts/syncthing-install.sh" status)
  jq -e '.state == "missing"' <<<"$output" >/dev/null \
    || fail "failed Flatpak lookup reported an installation"
}

test_modern_bundle() {
  local sandbox="$test_root/modern"
  local assets="$sandbox/gui" dependency relative before asset_before
  local helper="$root/hosts/omarchy/scripts/syncthing-theme.sh"
  mkdir -p -- "$sandbox/bin" "$assets/default"
  printf '%s\n' 'owner default' >"$assets/default/index.html"
  printf '%s\n' '#!/bin/bash' 'exit 1' >"$sandbox/bin/omarchy-theme-color"
  cp -- "$sandbox/bin/omarchy-theme-color" "$sandbox/bin/curl"
  chmod 700 -- "$sandbox/bin/"*

  PATH="$sandbox/bin:$PATH" bash "$helper" prepare modern "$assets" >/dev/null
  while IFS= read -r -d '' dependency; do
    relative=${dependency#"$root/webui/gui/syncshell-modern/"}
    [[ $relative == index.html || $relative == assets/css/theme.css ]] && continue
    cmp -s -- "$dependency" "$assets/syncshell-modern/$relative" \
      || fail "modern profile omitted or altered $relative"
  done < <(find "$root/webui/gui/syncshell-modern" -type f -print0)
  cmp -s -- "$root/webui/gui/syncshell-modern/index.html" \
    <(sed 's#assets/css/theme.css?v=[a-f0-9]*#assets/css/theme.css#g' \
      "$assets/syncshell-modern/index.html") \
    || fail "modern index changed beyond its stylesheet revision"
  for relative in dark light; do
    cmp -s -- "$root/webui/gui/syncshell-modern/assets/css/syncshell-$relative.css" \
      "$assets/syncshell-modern/assets/css/syncshell-$relative.css" \
      || fail "modern profile omitted the bundled $relative stylesheet"
  done
  ! grep -q 'theme-assets/' "$assets/syncshell-modern/assets/css/theme.css" \
    || fail "modern base still depends on daemon theme assets"
  [[ $(<"$assets/default/index.html") == 'owner default' ]] \
    || fail "modern preparation replaced default assets"
  [[ ! -e $assets/syncshell-modern/theme-version.txt ]] \
    || fail "modern preparation included the Omarchy palette updater"
  before=$(sha256sum "$assets/syncshell-modern/index.html")
  asset_before=$(stat -c '%i:%Y' "$assets/syncshell-modern/assets/img/favicon-default.png")
  bash "$helper" prepare modern "$assets" >/dev/null
  [[ $(sha256sum "$assets/syncshell-modern/index.html") == "$before"
      && $(stat -c '%i:%Y' "$assets/syncshell-modern/assets/img/favicon-default.png") == "$asset_before" ]] \
    || fail "unchanged modern bundle content changed or assets were recopied"

  local package="$sandbox/package"
  mkdir -p -- "$package/hosts/omarchy/scripts"
  cp -a -- "$root/webui" "$package/"
  cp -- "$helper" "$package/hosts/omarchy/scripts/"
  helper="$package/hosts/omarchy/scripts/syncthing-theme.sh"
  printf '%s\n' 'old bundle' >"$assets/syncshell-modern/.syncshell-bundle"
  printf '%s\n' 'obsolete' >"$assets/syncshell-modern/obsolete.js"
  rm -- "$package/webui/gui/syncshell-modern/index.html"
  if bash "$helper" prepare modern "$assets" >/dev/null 2>&1; then
    fail "incomplete modern bundle was selected"
  fi
  [[ $(sha256sum "$assets/syncshell-modern/index.html") == "$before" ]] \
    || fail "failed preparation replaced the working profile"
  cp -- "$root/webui/gui/syncshell-modern/index.html" "$package/webui/gui/syncshell-modern/index.html"
  bash "$helper" prepare modern "$assets" >/dev/null
  [[ ! -e $assets/syncshell-modern/obsolete.js ]] \
    || fail "bundle update retained obsolete assets"
  [[ -z $(find "$assets" -maxdepth 1 -name '.syncshell-modern.*' -print -quit) ]] \
    || fail "bundle preparation left a staging directory"
}

test_themes() {
  local theme colors version
  local themes_root="${OMARCHY_PATH:-/usr/share/omarchy}/themes"
  if [[ -d $themes_root ]]; then
    while IFS= read -r colors; do
      theme=$(basename -- "$(dirname -- "$colors")")
      bash "$root/hosts/omarchy/scripts/syncthing-theme.sh" prepare omarchy \
        "$test_root/themes/$theme" "$colors" >/dev/null
      grep -Fxq '@import "syncshell_base.css";' \
        "$test_root/themes/$theme/syncthing-omarchy/assets/css/theme.css" \
        || fail "$theme did not inherit the bundled base theme"
      ! grep -q '{{' "$test_root/themes/$theme/syncthing-omarchy/assets/css/omarchy_syncthing_theme.css" \
        || fail "$theme left unresolved palette values"
    done < <(find "$themes_root" -mindepth 2 -maxdepth 2 \
      -type f -name colors.toml -print | sort)
  fi

  local user_theme="$test_root/user-theme/colors.toml"
  local user_palette="$test_root/themes/user/syncthing-omarchy/assets/css/omarchy_syncthing_theme.css"
  mkdir -p -- "$(dirname -- "$user_theme")"
  printf '%s\n' \
    'background = "#120f18"' \
    'foreground = "#e8dff2"' \
    'accent = "#ff7ab2"' \
    'color1 = "#ff5370"' \
    'color2 = "#c3e88d"' \
    'color3 = "#ffcb6b"' \
    'color4 = "#82aaff"' \
    'color5 = "#c792ea"' \
    'color6 = "#89ddff"' \
    >"$user_theme"
  bash "$root/hosts/omarchy/scripts/syncthing-theme.sh" prepare omarchy \
    "$test_root/themes/user" "$user_theme" >/dev/null
  grep -Fxq '@import "syncshell_base.css";' \
    "$test_root/themes/user/syncthing-omarchy/assets/css/theme.css" \
    || fail "user theme did not inherit the bundled base theme"
  ! grep -q '{{' "$user_palette" \
    || fail "user theme left unresolved palette values"
  for color in '#120f18' '#e8dff2' '#ff7ab2' '#ff5370' '#c3e88d' \
      '#ffcb6b' '#82aaff' '#c792ea' '#89ddff'; do
    grep -Fq "$color" "$user_palette" \
      || fail "user theme omitted palette color $color"
  done

  local user_root="$test_root/themes/user/syncthing-omarchy"
  version=$(<"$user_root/theme-version.txt")
  [[ $version =~ ^[A-Za-z0-9._-]+$ ]] \
    || fail "generated theme version is invalid"
  grep -Fq "omarchy_syncthing_theme.css?v=$version" \
    "$user_root/assets/css/theme.css" \
    || fail "theme wrapper did not pin the generated palette"
  grep -Fq "data-theme-version=\"$version\"" "$user_root/index.html" \
    || fail "Web UI did not receive the generated theme version"
  grep -Fq 'src="assets/js/omarchy_theme_refresh.js"' \
    "$user_root/index.html" \
    || fail "Web UI did not load the theme refresh helper"
  cmp -s -- "$root/webui/integration/omarchy-theme-refresh.js" \
    "$user_root/assets/js/omarchy_theme_refresh.js" \
    || fail "generated theme refresh helper differs from its source"
  cmp -s -- "$test_root/modern/gui/syncshell-modern/assets/css/theme.css" \
    "$user_root/assets/css/syncshell_base.css" \
    || fail "Omarchy base differs from bundled modern CSS"
  local dependency
  while IFS= read -r -d '' dependency; do
    local relative=${dependency#"$root/webui/gui/syncshell-modern/"}
    [[ $relative == index.html || $relative == assets/css/theme.css ]] && continue
    cmp -s -- "$dependency" "$user_root/$relative" \
      || fail "Omarchy profile omitted or altered $relative"
  done < <(find "$root/webui/gui/syncshell-modern" -type f -print0)
  local asset_before
  asset_before=$(stat -c '%i:%Y' "$user_root/assets/img/favicon-default.png")
  bash "$root/hosts/omarchy/scripts/syncthing-theme.sh" prepare omarchy \
    "$test_root/themes/user" "$user_theme" >/dev/null
  [[ $(stat -c '%i:%Y' "$user_root/assets/img/favicon-default.png") == "$asset_before" ]] \
    || fail "palette refresh recopied static assets"
  [[ $(<"$user_root/theme-version.txt") != "$version" ]] \
    || fail "palette refresh did not advance its generation"

}

install_fake_plugin() {
  local source=$1
  local target=$2
  local install_kind=$3

  mkdir -p -- "$(dirname -- "$target")"
  if [[ $install_kind == link ]]; then
    mkdir -p -- "$source"
    cp -- "$root/manifest.json" "$source/manifest.json"
    ln -s -- "$source" "$target"
  else
    mkdir -p -- "$target"
    cp -- "$root/manifest.json" "$target/manifest.json"
  fi
}

test_removal_mode() {
  local mode=$1
  local install_kind=$2
  local sandbox="$test_root/removal-$mode-$install_kind"
  local source="$sandbox/source"
  local installed="$sandbox/config/omarchy/plugins/io.github.ilyazar.syncthing"
  local plugin_config="$sandbox/config/omarchy/ilyazar.syncthing"
  local gui_assets="$sandbox/gui"
  local fake_bin="$sandbox/bin"

  [[ $install_kind == link ]] || source=$installed
  install_fake_plugin "$source" "$installed" "$install_kind"
  mkdir -p -- "$plugin_config" \
    "$gui_assets/syncthing-omarchy/assets/css" \
    "$gui_assets/syncshell-modern" "$gui_assets/owner-theme" "$fake_bin"
  printf '%s\n' 'icon_style = "themed"' >"$plugin_config/settings.toml"
  printf '%s\n' 'generated' \
    >"$gui_assets/syncthing-omarchy/assets/css/theme.css"
  printf '%s\n' 'modern' >"$gui_assets/syncshell-modern/index.html"
  printf '%s\n' 'owner' >"$gui_assets/owner-theme/index.html"
  # Fake variables expand only when the generated command runs.
  # shellcheck disable=SC2016
  printf '%s\n' '#!/bin/bash' \
    'set -euo pipefail' \
    '[[ $1 == plugin && $2 == remove ]]' \
    'if [[ -L $FAKE_PLUGIN_TARGET ]]; then' \
    '  unlink -- "$FAKE_PLUGIN_TARGET"' \
    'else' \
    '  find "$FAKE_PLUGIN_TARGET" -depth -delete' \
    'fi' \
    >"$fake_bin/omarchy"
  printf '%s\n' '#!/bin/bash' 'exit 0' \
    >"$fake_bin/omarchy-notification-send"
  chmod 700 -- "$fake_bin/omarchy" "$fake_bin/omarchy-notification-send"

  HOME="$sandbox/home" \
    XDG_CONFIG_HOME="$sandbox/config" \
    XDG_STATE_HOME="$sandbox/state" \
    XDG_RUNTIME_DIR="$sandbox/runtime" \
    FAKE_PLUGIN_TARGET="$installed" \
    PATH="$fake_bin:$PATH" \
    bash "$root/hosts/omarchy/scripts/syncthing-remove.sh" _worker \
      "$source" "$gui_assets" "$mode"

  if [[ $install_kind == link ]]; then
    [[ -d $source ]] \
      || fail "$mode removal deleted the linked source checkout"
  else
    [[ ! -e $source ]] \
      || fail "$mode removal left the installed checkout"
  fi
  [[ ! -e $installed && ! -L $installed ]] \
    || fail "$mode removal left the installed link"
  [[ ! -e $gui_assets/syncthing-omarchy ]] \
    || fail "$mode removal left generated theme assets"
  [[ ! -e $gui_assets/syncshell-modern ]] \
    || fail "$mode removal left the modern profile"
  [[ $(<"$gui_assets/owner-theme/index.html") == owner ]] \
    || fail "$mode removal changed an unrelated theme"
  if [[ $mode == preserve ]]; then
    [[ -f $plugin_config/settings.toml ]] \
      || fail "preserve removal deleted plugin settings"
  else
    [[ ! -e $plugin_config ]] \
      || fail "purge removal left plugin settings"
  fi
}

if [[ ${1:-} == --installation-only ]]; then
  test_installation_status
  printf 'installation script tests passed\n'
  exit 0
fi

if [[ ${1:-} == --webui-only ]]; then
  test_modern_bundle
  printf 'webui installation tests passed\n'
  exit 0
fi

test_settings
test_installation_status
test_modern_bundle
test_themes
test_removal_mode preserve link
test_removal_mode purge link
test_removal_mode preserve directory
test_removal_mode purge directory
printf 'all script tests passed\n'
