#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$APP_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

install_neovim() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  brew_formula neovim
  link_config "$ROOT_DIR/nvim" "$HOME/.config/nvim"
}

linux() {
  apt_install neovim
  link_config "$ROOT_DIR/nvim" "$HOME/.config/nvim"
}

install_neovim "$1"
