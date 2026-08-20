#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_claude_code() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_configure() {
  safe_symlink_group 'Claude Code' \
    "$ROOT_DIR/.agents/AGENTS.md" "$HOME/.claude/AGENTS.md" \
    "$ROOT_DIR/.agents/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
}

mac() {
  brew_cask claude-code
  _configure
}

linux() {
  has claude || curl -fsSL https://claude.ai/install.sh | bash
  _configure
}

install_claude_code "$1"
