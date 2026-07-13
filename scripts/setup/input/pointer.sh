#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

configure_pointer() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  defaults write NSGlobalDomain CGDisableCursorLocationMagnification -bool false
  if ! {
    defaults write com.apple.universalaccess mouseDriverCursorSize -float 1
    defaults write com.apple.universalaccess cursorOutline -dict \
      red -float 0 green -float 0 blue -float 0 alpha -float 1
    defaults write com.apple.universalaccess cursorFill -dict \
      red -float 1 green -float 1 blue -float 1 alpha -float 1
    defaults write com.apple.universalaccess cursorIsCustomized -bool true
  } 2>/dev/null; then
    log 'macOS did not allow custom cursor colors; continuing.'
  fi
}

linux() {
  gsettings set org.gnome.desktop.interface locate-pointer true
  gsettings set org.gnome.desktop.interface cursor-size 24
  gsettings set org.gnome.desktop.interface cursor-theme Yaru
}

configure_pointer "$1"
