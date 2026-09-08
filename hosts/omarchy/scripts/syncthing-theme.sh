#!/bin/bash
set -euo pipefail

usage() {
  printf 'Usage: syncthing-theme.sh prepare <modern|omarchy> <gui-assets-dir> [colors.toml]\n' >&2
  exit 2
}

[[ ${1:-} == "prepare" && ( $# == 3 || $# == 4 ) ]] || usage
style=$2
assets_root=$3
colors_file=${4:-}
case $style in
  modern) theme_name=syncshell-modern ;;
  omarchy) theme_name=syncthing-omarchy ;;
  *) usage ;;
esac

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
bundle_root="$script_dir/../../../webui"
theme_root="$assets_root/$theme_name"
[[ ! -L $theme_root ]] || {
  printf 'Refusing to replace a linked Web UI directory\n' >&2
  exit 1
}
revision=$(sha256sum "$bundle_root/SHA256SUMS")
revision=${revision%% *}
staging=""
previous=""
temporary_files=()

cleanup() {
  rm -f -- "${temporary_files[@]}"
  if [[ -n $previous && -d $previous && ! -e $theme_root ]]; then
    mv -- "$previous" "$theme_root"
    previous=""
  fi
  [[ -z $staging ]] || rm -rf -- "$staging"
  [[ -z $previous ]] || rm -rf -- "$previous"
}
trap cleanup EXIT

base_stylesheet() {
  sed 's#../../theme-assets/\(dark\|light\)/assets/css/theme.css#syncshell-\1.css#g' \
    "$bundle_root/modern/assets/css/theme.css"
}

output_root=$theme_root
if [[ ! -f $theme_root/.syncshell-bundle
    || $(<"$theme_root/.syncshell-bundle") != "$revision" ]]; then
  (cd -- "$bundle_root" && sha256sum --quiet --check SHA256SUMS)
  mkdir -p -- "$assets_root"
  staging=$(mktemp -d -- "$assets_root/.$theme_name.XXXXXX")
  cp -a -- "$bundle_root/modern/." "$staging/"
  for theme in dark light; do
    cp -- "$bundle_root/themes/$theme.css" "$staging/assets/css/syncshell-$theme.css"
  done
  base_stylesheet >"$staging/assets/css/theme.css"
  cp -- "$bundle_root/LICENSE.syncthing" "$staging/"
  cp -a -- "$bundle_root/licenses" "$staging/"
  output_root=$staging
fi

if [[ $style == modern ]]; then
  index_tmp=$(mktemp --tmpdir="$output_root" .index.html.XXXXXX)
  temporary_files=("$index_tmp")
  sed "s#href=\"assets/css/theme.css\"#href=\"assets/css/theme.css?v=$revision\"#" \
    "$bundle_root/modern/index.html" >"$index_tmp"
  chmod 644 -- "$index_tmp"
  mv -- "$index_tmp" "$output_root/index.html"
fi

if [[ $style == omarchy ]]; then
  declare -A colors=()
  if [[ -n $colors_file ]]; then
    color_command=(omarchy-theme-color --file "$colors_file" --all)
  else
    color_command=(omarchy-theme-color --all)
  fi
  while IFS=$'\t' read -r key value; do
    [[ $key =~ ^[A-Za-z0-9_-]+$ ]] || continue
    [[ $value =~ ^#[0-9A-Fa-f]{6}$|^(dark|light)$ ]] || continue
    colors[$key]=$value
  done < <("${color_command[@]}")

  required=(
    background foreground accent muted selection
    lighter_background darker_background dark_foreground light_foreground
    red yellow green cyan blue magenta orange
  )
  for key in "${required[@]}"; do
    [[ -n ${colors[$key]:-} ]] || {
      printf 'Omarchy theme is missing the resolved color %s\n' "$key" >&2
      exit 1
    }
  done

  theme_dir="$output_root/assets/css"
  js_dir="$output_root/assets/js"
  mkdir -p -- "$theme_dir" "$js_dir"
  wrapper_tmp=$(mktemp --tmpdir="$theme_dir" .theme.css.XXXXXX)
  palette_tmp=$(mktemp --tmpdir="$theme_dir" .omarchy-theme.css.XXXXXX)
  refresh_tmp=$(mktemp --tmpdir="$js_dir" .omarchy-theme-refresh.js.XXXXXX)
  index_tmp=$(mktemp --tmpdir="$output_root" .index.html.XXXXXX)
  version_tmp=$(mktemp --tmpdir="$output_root" .theme-version.txt.XXXXXX)
  temporary_files=("$wrapper_tmp" "$palette_tmp" "$refresh_tmp"
    "$index_tmp" "$version_tmp")
  generation="${EPOCHREALTIME//[.,]/}-$RANDOM"

  printf '%s\n' \
    "/* omarchy-generation: $generation */" \
    '@import "syncshell_base.css";' \
    "@import \"omarchy_syncthing_theme.css?v=$generation\";" \
    >"$wrapper_tmp"

  sed \
    -e "s/{{background}}/${colors[background]}/g" \
    -e "s/{{foreground}}/${colors[foreground]}/g" \
    -e "s/{{accent}}/${colors[accent]}/g" \
    -e "s/{{muted}}/${colors[muted]}/g" \
    -e "s/{{selection}}/${colors[selection]}/g" \
    -e "s/{{surface}}/${colors[lighter_background]}/g" \
    -e "s/{{surface_dark}}/${colors[darker_background]}/g" \
    -e "s/{{foreground_dark}}/${colors[dark_foreground]}/g" \
    -e "s/{{foreground_light}}/${colors[light_foreground]}/g" \
    -e "s/{{red}}/${colors[red]}/g" \
    -e "s/{{yellow}}/${colors[yellow]}/g" \
    -e "s/{{green}}/${colors[green]}/g" \
    -e "s/{{cyan}}/${colors[cyan]}/g" \
    -e "s/{{blue}}/${colors[blue]}/g" \
    -e "s/{{magenta}}/${colors[magenta]}/g" \
    -e "s/{{orange}}/${colors[orange]}/g" \
    "$(dirname -- "$0")/../webui/omarchy_syncthing_theme.css" \
    >"$palette_tmp"

  grep -q '{{' "$palette_tmp" && {
    printf 'Generated Syncthing theme contains unresolved colors\n' >&2
    exit 1
  }

  sed \
    -e "s#href=\"assets/css/theme.css\"#href=\"assets/css/theme.css?v=$generation\"#" \
    -e "s#</head>#  <script defer src=\"assets/js/omarchy_theme_refresh.js\" data-theme-version=\"$generation\"></script>\n</head>#" \
    "$bundle_root/modern/index.html" >"$index_tmp"
  cp -- "$script_dir/../webui/omarchy_theme_refresh.js" "$refresh_tmp"
  base_stylesheet >"$theme_dir/syncshell_base.css"
  printf '%s\n' "$generation" >"$version_tmp"
  chmod 644 -- "${temporary_files[@]}"
  mv -- "$palette_tmp" "$theme_dir/omarchy_syncthing_theme.css"
  mv -- "$wrapper_tmp" "$theme_dir/theme.css"
  mv -- "$refresh_tmp" "$js_dir/omarchy_theme_refresh.js"
  mv -- "$index_tmp" "$output_root/index.html"
  mv -- "$version_tmp" "$output_root/theme-version.txt"
fi

if [[ -n $staging ]]; then
  printf '%s\n' "$revision" >"$staging/.syncshell-bundle"
  if [[ -e $theme_root ]]; then
    previous="$staging.previous"
    mv -- "$theme_root" "$previous"
  fi
  mv -- "$staging" "$theme_root"
  staging=""
fi

printf '%s\n' "$theme_root"
