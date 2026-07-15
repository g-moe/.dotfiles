#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$APP_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib.sh"

install_nordvpn() {
  if ! ask_binary 'Install NordVPN?'; then
    return
  fi
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  brew_cask nordvpn
}

linux() {
  local installer

  installer="$(mktemp)"
  curl -fsSL https://downloads.nordcdn.com/apps/linux/install.sh -o "$installer"
  /bin/bash "$installer" -n -p nordvpn-gui
  rm -f "$installer"
}

install_nordvpn "$1"
