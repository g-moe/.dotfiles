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
  defaults write NSGlobalDomain AppleActionOnDoubleClick -string Fill
  defaults write NSGlobalDomain AppleMiniaturizeOnDoubleClick -bool false
  defaults write com.apple.WindowManager EnableTilingByEdgeDrag -bool false
  defaults write com.apple.WindowManager EnableTopTilingByEdgeDrag -bool false
  defaults write com.apple.WindowManager EnableTilingOptionAccelerator -bool false
  defaults write com.apple.WindowManager EnableTiledWindowMargins -bool true
}

linux() {
  log 'Xfce window changes are not part of this install.'
}

configure_windows "$1"
