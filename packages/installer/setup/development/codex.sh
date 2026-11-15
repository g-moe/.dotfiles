#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

CODEX_SYSTEM_DIR=/etc/codex

configure_codex() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_configure() {
  # Shared settings are Codex's system config, which Codex reads but never writes.
  # ~/.codex/config.toml stays a plain file for this machine's paths and app state, and it overrides the shared file.
  chmod 0600 "$ROOT_DIR/codex/.codex/config.toml"
  sudo mkdir -p "$CODEX_SYSTEM_DIR"
  sudo ln -sfn "$ROOT_DIR/codex/.codex/config.toml" "$CODEX_SYSTEM_DIR/config.toml"
  safe_symlink_group 'Codex' \
    "$ROOT_DIR/codex/.codex/keybindings.json" "$HOME/.codex/keybindings.json"
}

mac() {
  _configure
}

linux() {
  _configure
}

configure_codex "$1"
