#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_fastfetch() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  brew_formula fastfetch
}

linux() {
  apt_install fastfetch
}

install_fastfetch "$1"
