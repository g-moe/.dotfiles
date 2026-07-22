#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_codex() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_configure() {
  chmod 0600 "$ROOT_DIR/codex/.codex/config.toml"
  safe_symlink_group 'Codex' \
    "$ROOT_DIR/codex/.codex/AGENTS.md" "$HOME/.codex/AGENTS.md" \
    "$ROOT_DIR/codex/.codex/config.toml" "$HOME/.codex/config.toml"
}

mac() {
  _configure
}

linux() {
  _configure
}

configure_codex "$1"
