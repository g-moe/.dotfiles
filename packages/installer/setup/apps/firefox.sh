#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_firefox() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  brew_cask firefox
  [[ -d /Applications/Firefox.app ]] || die 'Firefox is missing after installation.'
}

linux() {
  apt_install firefox-esr
  has firefox-esr || die 'Firefox ESR is missing after installation.'
}

install_firefox "$1"
