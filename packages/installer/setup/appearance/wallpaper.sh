#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_wallpaper() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_wallpaper_path() {
  local color color_hex color_key image_path output_size temporary_dir temporary_path

  color="$(machine_field "$ROOT_DIR/machine.json" color)"
  color_hex="$(machine_color_hex "$color")"
  color_key="${color_hex#\#}"
  output_size=6016x3388
  image_path="$ROOT_DIR/.machine-wallpaper-$color_key-$output_size.png"
  if [[ ! -s "$image_path" ]]; then
    temporary_dir="$(mktemp -d "${TMPDIR:-/tmp}/machine-wallpaper.XXXXXX")"
    temporary_path="$temporary_dir/wallpaper.png"
    magick "$ROOT_DIR/images/white.png" \
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
    rm -rf "$temporary_dir"
    [[ -s "$image_path" ]] || die 'Wallpaper image is empty.'
  fi
  printf '%s\n' "$image_path"
}

mac() {
  local image_path
  ask_binary 'Set the machine-color wallpaper?' || return 0
  load_homebrew || die 'Homebrew is not installed.'
  image_path="$(_wallpaper_path)"
  /usr/bin/swift - "$image_path" <<'SWIFT'
import AppKit

let image = URL(fileURLWithPath: CommandLine.arguments[1])
for screen in NSScreen.screens {
  try NSWorkspace.shared.setDesktopImageURL(image, for: screen, options: [:])
}
SWIFT
}

linux() {
  local image_path property style_property
  local -a wallpaper_properties=()

  ask_binary 'Set the machine-color wallpaper?' || return 0
  apt_install imagemagick xfconf
  image_path="$(_wallpaper_path)"

  mapfile -t wallpaper_properties < <(
    xfconf-query -c xfce4-desktop -l | awk '/\/last-image$/ { print }'
  )
  ((${#wallpaper_properties[@]})) ||
    die 'Xfce has no wallpaper settings. Log into the Xfce desktop once, then run the appearance phase again.'

  for property in "${wallpaper_properties[@]}"; do
    xfconf-query -c xfce4-desktop -p "$property" -s "$image_path"
    style_property="${property%/last-image}/image-style"
    if silent xfconf-query -c xfce4-desktop -p "$style_property"; then
      xfconf-query -c xfce4-desktop -p "$style_property" -s 5
    else
      xfconf-query -c xfce4-desktop -p "$style_property" -n -t int -s 5
    fi

    [[ "$(xfconf-query -c xfce4-desktop -p "$property")" == "$image_path" ]] ||
      die "The Xfce wallpaper was not saved: $property"
    [[ "$(xfconf-query -c xfce4-desktop -p "$style_property")" == 5 ]] ||
      die "The Xfce wallpaper style was not saved: $style_property"
  done
}

configure_wallpaper "$1"
