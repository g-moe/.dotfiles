#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_zed_settings() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_configure() {
  safe_symlink_group 'Zed settings' \
    "$ROOT_DIR/zed/user/settings.json" "$HOME/.config/zed/settings.json" \
    "$ROOT_DIR/zed/user/keymap.json" "$HOME/.config/zed/keymap.json"
}

mac() {
  _configure
}

linux() {
  _configure
}

configure_zed_settings "$1"
