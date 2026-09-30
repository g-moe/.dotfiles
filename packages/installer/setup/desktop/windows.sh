#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_windows() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  return 0
}

linux() {
  local layout='CHM|'

  xfconf_set xfwm4 /general/button_layout string "$layout"
  xfconf_set xfwm4 /general/move_opacity int 92
  xfconf_set xfwm4 /general/resize_opacity int 92
  xfconf_set xfwm4 /general/popup_opacity int 98
  xfconf_set xfwm4 /general/placement_mode string center
  xfconf_set xfwm4 /general/show_dock_shadow bool false
  xfconf_set xfwm4 /general/show_popup_shadow bool false
  xfconf_set xfwm4 /general/use_compositing bool true
  [[ "$(xfconf-query -c xfwm4 -p /general/button_layout)" == "$layout" ]] ||
    die 'The Mac-style window-button order was not saved.'
}

configure_windows "$1"
