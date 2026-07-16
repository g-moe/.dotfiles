#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

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
  log 'Xfce desktop item changes are not part of this install.'
}

configure_desktop_items "$1"
