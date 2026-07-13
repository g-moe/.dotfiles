#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

configure_vscodium_settings() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_configure() {
  local target="$1"
  link_config "$ROOT_DIR/vscode/user/settings.json" "$target/settings.json"
  link_config "$ROOT_DIR/vscode/user/keybindings.json" "$target/keybindings.json"
}

mac() {
  _configure "$HOME/Library/Application Support/VSCodium/User"
}

linux() {
  _configure "$HOME/.config/VSCodium/User"
}

configure_vscodium_settings "$1"
