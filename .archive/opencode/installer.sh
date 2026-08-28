#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_opencode() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_configure() {
  local target="$HOME/.config/opencode"

  safe_symlink_group OpenCode \
    "$ROOT_DIR/opencode/opencode.jsonc" "$target/opencode.jsonc" \
    "$ROOT_DIR/opencode/tui.jsonc" "$target/tui.jsonc" \
    "$ROOT_DIR/opencode/themes/gtheme.json" "$target/themes/gtheme.json"
}

mac() {
  brew_cask opencode-desktop
  _configure
}

linux() {
  local package

  package="$(download_github_asset anomalyco/opencode \
    "opencode-desktop-linux-${LINUX_ARCH}\\.deb$" .deb)"
  apt_install "$package"
  rm -f "$package"
  _configure
}

install_opencode "$1"
