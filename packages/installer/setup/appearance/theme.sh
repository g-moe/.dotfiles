#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_theme() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  local color tint
  ask_binary 'Set the dark theme and machine color?' || return 0
  color="$(machine_field "$ROOT_DIR/machine.json" color)"
  tint="$(machine_color_tint "$color")"
  defaults write NSGlobalDomain AppleAccentColor -int 4
  defaults write NSGlobalDomain AppleHighlightColor -string '0.698039 0.843137 1.000000 Blue'
  defaults write NSGlobalDomain AppleInterfaceStyle -string Dark
  defaults write NSGlobalDomain NSGlassDiffusionSetting -int 0
  defaults write NSGlobalDomain AppleReduceDesktopTinting -bool true
  defaults write NSGlobalDomain AppleIconAppearanceTheme -string ClearLight
  defaults write NSGlobalDomain AppleIconAppearanceTintColor -string Other
  defaults write NSGlobalDomain AppleIconAppearanceCustomTintColor -string "$tint"
}

linux() {
  log 'Xfce theme changes are not part of this install.'
}

configure_theme "$1"
