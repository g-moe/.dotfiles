#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

configure_wallpaper() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_wallpaper_path() {
  local color color_hex color_key image_path output_size temporary_path

  color="$(machine_field "$ROOT_DIR/machine.json" color)"
  color_hex="$(machine_color_hex "$color")"
  color_key="${color_hex#\#}"
  output_size=6016x3388
  [[ "$OS" != linux ]] || output_size=3840x2160
  image_path="$ROOT_DIR/.machine-wallpaper-$color_key-$output_size.png"
  if [[ ! -s "$image_path" ]]; then
    temporary_path="$(mktemp "${TMPDIR:-/tmp}/machine-wallpaper.XXXXXX.png")"
    magick "$ROOT_DIR/white.png" \
      -rotate 180 \
      -colorspace gray \
      +level-colors '#000000',"$color_hex" \
      -resize "$output_size!" \
      "$temporary_path" || die 'Could not color the wallpaper.'
    magick "$temporary_path" \
      \( -size 1504x847 radial-gradient:white-black +level '25%,100%' -resize "$output_size!" \) \
      -compose multiply \
      -composite \
      "$image_path" || die 'Could not create the wallpaper.'
    rm -f "$temporary_path"
    [[ -s "$image_path" ]] || die 'Wallpaper image is empty.'
  fi
  printf '%s\n' "$image_path"
}

mac() {
  local image_path
  confirm 'Set the machine-color wallpaper?' || return 0
  image_path="$(_wallpaper_path)"
  osascript - "$image_path" <<'APPLESCRIPT'
on run argv
  set wallpaperPath to POSIX file (item 1 of argv)
  tell application "System Events"
    repeat with i from 1 to count of desktops
      set picture of desktop i to wallpaperPath
      delay 0.2
    end repeat
  end tell
end run
APPLESCRIPT
}

linux() {
  local image_path uri
  confirm 'Set the machine-color wallpaper?' || return 0
  image_path="$(_wallpaper_path)"
  uri="file://$image_path"
  gsettings set org.gnome.desktop.background picture-uri "$uri"
  gsettings set org.gnome.desktop.background picture-uri-dark "$uri"
  gsettings set org.gnome.desktop.background picture-options zoom
}

configure_wallpaper "$1"
