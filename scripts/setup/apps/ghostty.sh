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

mac() {
  brew_cask ghostty
  safe_symlink "$ROOT_DIR/ghostty" "$HOME/.config/ghostty"
  [[ -d /Applications/Ghostty.app ]] || die 'Ghostty is missing after installation.'
}

linux() {
  apt_install ghostty
  safe_symlink "$ROOT_DIR/ghostty" "$HOME/.config/ghostty"
  has ghostty || die 'Ghostty is missing after installation.'
}

install_ghostty "$1"
