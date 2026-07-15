#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib.sh"

configure_widgets() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  defaults write com.apple.WindowManager StandardHideWidgets -bool true
  defaults write com.apple.WindowManager StageManagerHideWidgets -bool true
}

linux() {
  log 'GNOME does not place widgets on the desktop.'
}

configure_widgets "$1"
