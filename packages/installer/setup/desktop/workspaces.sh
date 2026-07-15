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
  gsettings set org.gnome.mutter dynamic-workspaces false
  gsettings set org.gnome.desktop.wm.preferences num-workspaces 4
  gsettings set org.gnome.mutter workspaces-only-on-primary false
  gsettings set org.gnome.desktop.wm.preferences focus-new-windows smart
  gsettings set org.gnome.shell.app-switcher current-workspace-only false
}

configure_workspaces "$1"
