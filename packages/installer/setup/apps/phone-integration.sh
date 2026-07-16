#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_phone_integration() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  log 'iPhone Mirroring is built into macOS.'
}

linux() {
  apt_install gnome-shell-extension-gsconnect gnome-shell-extension-gsconnect-browsers
}

install_phone_integration "$1"
