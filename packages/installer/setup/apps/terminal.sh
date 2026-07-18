#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_terminal() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_configure() {
  local target="$HOME/.config/ghostty"

  safe_symlink_group Ghostty \
    "$ROOT_DIR/ghostty/config" "$target/config" \
    "$ROOT_DIR/ghostty/themes/gtheme-dark" "$target/themes/gtheme-dark" \
    "$ROOT_DIR/ghostty/themes/gtheme-light" "$target/themes/gtheme-light"
}

mac() {
  brew_cask ghostty
  _configure
  [[ -d /Applications/Ghostty.app ]] || die 'Ghostty is missing after installation.'
}

linux() {
  local color color_hex

  apt_install xfconf
  color="$(machine_field "$ROOT_DIR/machine.json" color)"
  color_hex="$(machine_color_hex "$color")"

  xfconf_set xfce4-terminal /font-use-system bool false
  xfconf_set xfce4-terminal /font-name string 'JetBrains Mono 12'
  xfconf_set xfce4-terminal /misc-menubar-default bool false
  xfconf_set xfce4-terminal /misc-toolbar-default bool false
  xfconf_set xfce4-terminal /misc-borders-default bool true
  xfconf_set xfce4-terminal /misc-always-show-tabs bool false
  xfconf_set xfce4-terminal /scrolling-bar string TERMINAL_SCROLLBAR_NONE
  xfconf_set xfce4-terminal /background-mode string TERMINAL_BACKGROUND_SOLID
  xfconf_set xfce4-terminal /background-darkness double 1.0
  xfconf_set xfce4-terminal /color-background string '#111817'
  xfconf_set xfce4-terminal /color-foreground string '#ebdbb2'
  xfconf_set xfce4-terminal /color-cursor string "$color_hex"
  xfconf_set xfce4-terminal /color-cursor-use-default bool false
  xfconf_set xfce4-terminal /color-selection string "$color_hex"
  xfconf_set xfce4-terminal /color-selection-use-default bool false
  xfconf_set xfce4-terminal /color-bold string '#fbf1c7'
  xfconf_set xfce4-terminal /color-bold-use-default bool false
  xfconf_set xfce4-terminal /color-palette string \
    '#1d2021;#cc241d;#98971a;#d79921;#458588;#b16286;#689d6a;#a89984;#928374;#fb4934;#b8bb26;#fabd2f;#83a598;#d3869b;#8ec07c;#ebdbb2'
  xfconf_set xfce4-terminal /tab-activity-color string "$color_hex"

  [[ "$(xfconf-query -c xfce4-terminal -p /font-name)" == 'JetBrains Mono 12' ]] ||
    die 'The Xfce Terminal font was not saved.'
  [[ "$(xfconf-query -c xfce4-terminal -p /misc-borders-default)" == true ]] ||
    die 'The Xfce Terminal window borders were not enabled.'
}

install_terminal "$1"
