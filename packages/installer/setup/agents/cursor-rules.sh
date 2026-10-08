#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_cursor_rules() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_configure() {
  activate_repo_node "$ROOT_DIR" || die 'Node.js is not available.'

  # Cursor skips external plugin symlinks. Copy the rule into its local plugin
  # directory and check the copy so later instruction edits cannot go unnoticed.
  node "$STRATEGY_DIR/cursor-rules.mjs" write "$ROOT_DIR/.agents/AGENTS.md" "$HOME"
  node "$STRATEGY_DIR/cursor-rules.mjs" check "$ROOT_DIR/.agents/AGENTS.md" "$HOME"
}

mac() {
  _configure
}

linux() {
  _configure
}

configure_cursor_rules "$1"
