#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_terminal() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_configure() {
  local target="$HOME/.config/ghostty"

  safe_symlink_group Ghostty \
    "$ROOT_DIR/ghostty/config" "$target/config" \
    "$ROOT_DIR/ghostty/themes/gtheme-dark" "$target/themes/gtheme-dark" \
    "$ROOT_DIR/ghostty/themes/gtheme-light" "$target/themes/gtheme-light"
}

mac() {
  brew_cask ghostty
  _configure
  [[ -d /Applications/Ghostty.app ]] || die 'Ghostty is missing after installation.'
}

linux() {
  return 0
}

install_terminal "$1"
