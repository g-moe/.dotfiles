#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

configure_file_preferences() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write com.apple.finder FXRemoveOldTrashItems -bool true
  defaults write com.apple.finder FXDefaultSearchScope -string SCcf
  defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false
  defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false
  defaults write com.apple.finder NewWindowTarget -string PfHm
  defaults write com.apple.finder NewWindowTargetPath -string "file://$HOME/"
  defaults write com.apple.finder FXPreferredViewStyle -string clmv
  defaults write com.apple.finder ShowPathbar -bool true
  defaults write com.apple.finder ShowStatusBar -bool true
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  killall Finder >/dev/null 2>&1 || true
}

linux() {
  gsettings set org.gnome.desktop.privacy remove-old-trash-files true
  gsettings set org.gnome.desktop.privacy old-files-age 30
  gsettings set org.gnome.nautilus.preferences recursive-search local-only
  gsettings set org.gnome.nautilus.preferences default-folder-viewer list-view
  gsettings set org.gnome.shell.extensions.ding show-volumes false
}

configure_file_preferences "$1"
