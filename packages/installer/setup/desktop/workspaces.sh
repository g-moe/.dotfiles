#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_workspaces() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  defaults write com.apple.dock mru-spaces -bool false
  defaults write NSGlobalDomain AppleSpacesSwitchOnActivate -bool false
  defaults write com.apple.dock workspaces-auto-swoosh -bool false
  defaults write com.apple.dock expose-group-apps -bool false
  defaults write com.apple.spaces spans-displays -bool false
  defaults write com.apple.dock enterMissionControlByTopWindowDrag -bool false
  defaults write com.apple.dock wvous-br-corner -int 2
  defaults write com.apple.dock wvous-br-modifier -int 131072
}

linux() {
  log 'Xfce workspace changes are not part of this install.'
  return 0
}

configure_workspaces "$1"
