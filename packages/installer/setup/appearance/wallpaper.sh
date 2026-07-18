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
  local color color_hex color_key image_path output_size

  color="$(machine_field "$ROOT_DIR/machine.json" color)"
  color_hex="$(machine_color_hex "$color")"
  color_key="${color_hex#\#}"
  output_size=6016x3388
  image_path="$ROOT_DIR/.machine-wallpaper-$color_key-$output_size.png"
  if [[ ! -s "$image_path" ]]; then
    render_machine_background \
      "$ROOT_DIR/images/white.png" "$color_hex" "$output_size" "$image_path"
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
  local image_path monitor property style_property workspace workspace_count
  local -a active_monitors=() wallpaper_properties=()

  ask_binary 'Set the machine-color wallpaper?' || return 0
  apt_install imagemagick xfconf x11-xserver-utils
  image_path="$(_wallpaper_path)"

  mapfile -t active_monitors < <(
    xrandr --listactivemonitors | awk 'NR > 1 { print $NF }'
  )
  ((${#active_monitors[@]})) ||
    die 'Xfce has no active monitor. Log into the Xfce desktop, then run the appearance phase again.'

  workspace_count="$(
    xfconf-query -c xfwm4 -p /general/workspace_count 2>/dev/null || true
  )"
  [[ "$workspace_count" =~ ^[1-9][0-9]*$ ]] || workspace_count=1

  mapfile -t wallpaper_properties < <(
    {
      xfconf-query -c xfce4-desktop -l | awk '/\/last-image$/ { print }'
      for monitor in "${active_monitors[@]}"; do
        for ((workspace = 0; workspace < workspace_count; workspace++)); do
          printf '/backdrop/screen0/monitor%s/workspace%s/last-image\n' \
            "$monitor" "$workspace"
        done
      done
    } | sort -u
  )

  for property in "${wallpaper_properties[@]}"; do
    xfconf_set xfce4-desktop "$property" string "$image_path"
    style_property="${property%/last-image}/image-style"
    xfconf_set xfce4-desktop "$style_property" int 5

    [[ "$(xfconf-query -c xfce4-desktop -p "$property")" == "$image_path" ]] ||
      die "The Xfce wallpaper was not saved: $property"
    [[ "$(xfconf-query -c xfce4-desktop -p "$style_property")" == 5 ]] ||
      die "The Xfce wallpaper style was not saved: $style_property"
  done

  silent xfdesktop --reload || die 'Xfce could not reload the wallpaper settings.'
}

configure_wallpaper "$1"
