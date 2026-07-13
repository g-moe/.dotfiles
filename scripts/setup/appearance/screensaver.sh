#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

configure_screensaver() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  local path='/System/Library/ExtensionKit/Extensions/Flurry.appex'
  [[ -d "$path" ]] || die "Missing built-in Flurry screen saver: $path"
  defaults -currentHost write com.apple.screensaver moduleDict -dict \
    moduleName Flurry path "$path" type -int 0
  defaults -currentHost write com.apple.screensaver idleTime -int 0
}

linux() {
  gsettings set org.gnome.desktop.session idle-delay 'uint32 0'
  gsettings set org.gnome.desktop.screensaver lock-enabled false
}

configure_screensaver "$1"
