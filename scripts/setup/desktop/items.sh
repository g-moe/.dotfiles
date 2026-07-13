#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

configure_desktop_items() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  defaults write com.apple.WindowManager StandardHideDesktopIcons -bool true
  defaults write com.apple.WindowManager HideDesktop -bool true
  defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false
  defaults write com.apple.WindowManager GloballyEnabled -bool false
  defaults write com.apple.WindowManager AutoHide -bool true
  defaults write com.apple.WindowManager AppWindowGroupingBehavior -int 1
}

linux() {
  gsettings set org.gnome.shell.extensions.ding show-home false
  gsettings set org.gnome.shell.extensions.ding show-trash false
  gsettings set org.gnome.shell.extensions.ding show-volumes false
  gsettings set org.gnome.shell.extensions.ding show-network-volumes false
}

configure_desktop_items "$1"
