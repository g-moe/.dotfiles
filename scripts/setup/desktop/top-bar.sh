#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

configure_top_bar() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  defaults -currentHost write com.apple.controlcenter Battery -int 8
  defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -int 0
  defaults -currentHost write com.apple.controlcenter Bluetooth -int 24
  defaults -currentHost write com.apple.controlcenter Display -int 8
  defaults -currentHost write com.apple.controlcenter FocusModes -int 8
  defaults -currentHost write com.apple.controlcenter KeyboardBrightness -int 8
  defaults -currentHost write com.apple.controlcenter NowPlaying -int 8
  defaults -currentHost write com.apple.controlcenter ScreenMirroring -int 8
  defaults -currentHost write com.apple.controlcenter Sound -int 8
  defaults -currentHost write com.apple.controlcenter TimeMachine -int 8
  defaults -currentHost write com.apple.controlcenter VoiceControl -int 8
  defaults -currentHost write com.apple.controlcenter WiFi -int 8
  defaults write com.apple.controlcenter 'NSStatusItem Visible AirDrop' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Battery' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible BentoBox' -bool true
  defaults write com.apple.controlcenter 'NSStatusItem Visible Bluetooth' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible FaceTime' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible FocusModes' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Item-0' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Item-1' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Item-2' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Item-3' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Item-4' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Item-5' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Item-6' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Item-7' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Item-8' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Item-9' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible ScreenMirroring' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Shortcuts' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Sound' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem VisibleCC BentoBox-0' -bool true
  defaults write com.apple.controlcenter 'NSStatusItem VisibleCC Clock' -bool true
  defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1
  defaults write com.apple.controlcenter AutoHideMenuBarOption -int 3
  defaults write NSGlobalDomain _HIHideMenuBar -bool false
  defaults write NSGlobalDomain AppleMenuBarVisibleInFullscreen -bool true
  defaults write NSGlobalDomain NSRecentDocumentsLimit -int 0
  defaults write NSGlobalDomain AppleEnableMenuBarTransparency -bool true || true
  defaults write com.apple.menuextra.clock DateFormat -string 'MMM d HH:mm:ss'
  defaults write com.apple.menuextra.clock IsAnalog -bool false
  defaults write com.apple.menuextra.clock Show24Hour -bool true
  defaults write com.apple.menuextra.clock ShowSeconds -bool true
  defaults write com.apple.menuextra.clock ShowAMPM -bool false
  defaults write com.apple.menuextra.clock ShowDayOfWeek -bool false
  defaults write com.apple.menuextra.clock ShowDayOfMonth -bool true
  defaults write com.apple.menuextra.clock ShowDate -int 0
  killall ControlCenter >/dev/null 2>&1 || true
  killall SystemUIServer >/dev/null 2>&1 || true
}

linux() {
  gsettings set org.gnome.desktop.interface clock-format 24h
  gsettings set org.gnome.desktop.interface clock-show-date true
  gsettings set org.gnome.desktop.interface clock-show-seconds true
  gsettings set org.gnome.desktop.interface clock-show-weekday false
  gsettings set org.gnome.desktop.interface show-battery-percentage false
  enable_gnome_extension gsconnect@andyholmes.github.io
  enable_gnome_extension system-monitor@gnome-shell-extensions.gcampax.github.com
}

configure_top_bar "$1"
