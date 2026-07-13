#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$APP_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

install_clipboard_tools() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  log 'pbcopy and pbpaste are built into macOS.'
}

linux() {
  apt_install wl-clipboard xclip
}

install_clipboard_tools "$1"
