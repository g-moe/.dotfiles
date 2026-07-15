#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$APP_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
. "$SCRIPTS_DIR/lib/lib.sh"

install_ghostty() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_configure() {
  local target="$HOME/.config/ghostty"

  safe_symlink "$ROOT_DIR/ghostty/config" "$target/config"
  safe_symlink "$ROOT_DIR/ghostty/themes/gtheme-dark" "$target/themes/gtheme-dark"
  safe_symlink "$ROOT_DIR/ghostty/themes/gtheme-light" "$target/themes/gtheme-light"
}

mac() {
  brew_cask ghostty
  _configure
  [[ -d /Applications/Ghostty.app ]] || die 'Ghostty is missing after installation.'
}

linux() {
  apt_install ghostty
  _configure
  has ghostty || die 'Ghostty is missing after installation.'
}

install_ghostty "$1"
