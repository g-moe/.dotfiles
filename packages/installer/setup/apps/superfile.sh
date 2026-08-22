#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_superfile() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_configure() {
  local target

  case "$1" in
    mac) target="$HOME/Library/Application Support/superfile" ;;
    linux) target="$HOME/.config/superfile" ;;
    *) die "Unsupported OS: $1" ;;
  esac

  safe_symlink_group Superfile \
    "$ROOT_DIR/superfile/config.toml" "$target/config.toml" \
    "$ROOT_DIR/superfile/theme/gtheme.toml" "$target/theme/gtheme.toml"
}

mac() {
  brew_formula superfile
  _configure mac
}

linux() {
  if ! has spf; then
    bash -c "$(curl -fsSL https://superfile.dev/install.sh)"
  fi
  _configure linux
}

install_superfile "$1"
