#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_touchpad() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_mac_trackpad_domain() {
  local domain="$1"
  defaults write "$domain" FirstClickThreshold -int 0
  defaults write "$domain" ActuationEnabled -bool false
  defaults write "$domain" ForceSuppressed -bool true
  defaults write "$domain" ActuateDetents -bool false
  defaults write "$domain" TrackpadRightClick -bool true
  defaults write "$domain" TrackpadCornerSecondaryClick -int 0
  defaults write "$domain" Clicking -bool true
  defaults write "$domain" TrackpadScroll -bool false
  defaults write "$domain" TrackpadPinch -bool false
  defaults write "$domain" TrackpadTwoFingerDoubleTapGesture -bool false
  defaults write "$domain" TrackpadRotate -bool false
  defaults write "$domain" TrackpadTwoFingerFromRightEdgeSwipeGesture -int 0
  defaults write "$domain" TrackpadThreeFingerHorizSwipeGesture -int 2
  defaults write "$domain" TrackpadFourFingerHorizSwipeGesture -int 0
  defaults write "$domain" TrackpadThreeFingerVertSwipeGesture -int 0
  defaults write "$domain" TrackpadFourFingerVertSwipeGesture -int 2
  defaults write "$domain" TrackpadFourFingerPinchGesture -int 0
  defaults write "$domain" TrackpadThreeFingerTapGesture -int 0
}

mac() {
  defaults write NSGlobalDomain com.apple.trackpad.scaling -float 3
  _mac_trackpad_domain com.apple.AppleMultitouchTrackpad
  _mac_trackpad_domain com.apple.driver.AppleBluetoothMultitouch.trackpad
  defaults write NSGlobalDomain AppleEnableSwipeNavigateWithScrolls -bool false
  defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
  defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
  defaults write com.apple.dock showMissionControlGestureEnabled -bool true
  defaults write com.apple.dock showAppExposeGestureEnabled -bool false
  defaults write com.apple.dock showDesktopGestureEnabled -bool false
  if [[ -x /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings ]]; then
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u || true
  fi
}

linux() {
  gsettings set org.gnome.desktop.peripherals.touchpad speed 1.0
  gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
  gsettings set org.gnome.desktop.peripherals.touchpad click-method fingers
  gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false
  gsettings set org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled false
  gsettings set org.gnome.desktop.peripherals.touchpad edge-scrolling-enabled false
  gsettings set org.gnome.desktop.peripherals.touchpad send-events enabled
}

configure_touchpad "$1"
