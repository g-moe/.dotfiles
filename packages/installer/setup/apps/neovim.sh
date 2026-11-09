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

_remove_broken_links() {
  local source_root="$1"
  local target_root="$2"
  local link

  [[ -d "$target_root" ]] || return 0
  while IFS= read -r -d '' link; do
    [[ ! -e "$link" && "$(readlink "$link")" == "$source_root/"* ]] || continue
    rm -- "$link"
  done < <(find "$target_root" -type l -print0)
}

_configure() {
  local relative source target="$HOME/.config/nvim"
  local links=()

  _remove_broken_links "$ROOT_DIR/nvim" "$target"

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

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  install_neovim "$1"
fi
