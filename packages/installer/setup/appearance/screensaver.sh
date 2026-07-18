#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

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
  log 'Xfce screen saver changes are not part of this install.'
  return 0
}

configure_screensaver "$1"
