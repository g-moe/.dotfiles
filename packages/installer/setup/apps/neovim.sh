#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_neovim() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_configure() {
  local relative source target="$HOME/.config/nvim"
  local links=()

  while IFS= read -r source; do
    relative="${source#"$ROOT_DIR/nvim/"}"
    links+=("$source" "$target/$relative")
  done < <(find "$ROOT_DIR/nvim" -type f | sort)

  safe_symlink_group Neovim "${links[@]}"
}

mac() {
  brew_formula neovim
  _configure
}

linux() {
  apt_install neovim
  _configure
}

install_neovim "$1"
