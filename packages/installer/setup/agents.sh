#!/usr/bin/env bash
set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$SETUP_DIR/.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_agents() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_link_instructions() {
  safe_symlink_group 'Agent instructions' \
    "$ROOT_DIR/.agents/AGENTS.md" "$HOME/.codex/AGENTS.md" \
    "$ROOT_DIR/.agents/AGENTS.md" "$HOME/.pi/agent/AGENTS.md" \
    "$ROOT_DIR/.agents/AGENTS.md" "$HOME/.claude/AGENTS.md" \
    "$ROOT_DIR/.agents/CLAUDE.md" "$HOME/.claude/CLAUDE.md" \
    "$ROOT_DIR/claude/settings.json" "$HOME/.claude/settings.json"
}

_install_agent_usage() {
  activate_repo_node "$ROOT_DIR" || die 'Run --development before --agents so Node.js is available.'
  if [[ ! -x "$ROOT_DIR/node_modules/.bin/tsc" ]]; then
    (cd "$ROOT_DIR" && npm ci)
  fi
  "$ROOT_DIR/node_modules/.bin/tsc" -p "$ROOT_DIR/packages/agent-usage/tsconfig.json"
  chmod +x "$ROOT_DIR/packages/agent-usage/dist/cli/main.js"
  mkdir -p "$HOME/.local/bin"
  safe_symlink_group 'Agent usage CLI' \
    "$ROOT_DIR/packages/agent-usage/dist/cli/main.js" "$HOME/.local/bin/agent-usage"
}

mac() {
  _link_instructions
  _install_agent_usage
}

linux() {
  _link_instructions
  _install_agent_usage
}

[[ "$#" -eq 1 ]] || die 'Run via: bash packages/installer/install.sh --agents'
install_agents "$1"
