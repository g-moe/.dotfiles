#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$APP_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
. "$SCRIPTS_DIR/lib/lib.sh"

install_opencode() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  brew_cask opencode-desktop
  safe_symlink "$ROOT_DIR/opencode" "$HOME/.config/opencode"
}

linux() {
  local package

  package="$(download_github_asset anomalyco/opencode \
    "opencode-desktop-linux-${LINUX_ARCH}\\.deb$" .deb)"
  apt_install "$package"
  rm -f "$package"
  safe_symlink "$ROOT_DIR/opencode" "$HOME/.config/opencode"
}

install_opencode "$1"
