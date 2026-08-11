#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

# Configure global MCP servers for Codex and Claude Code.
#
# Add one _register call to _configure for each server:
#   _register <name> <command> [arguments...]
#
# Example:
#   _register chrome-devtools npx --yes chrome-devtools-mcp@latest
#
# Dotfiles owns each registered name. Each run removes the old definition and
# adds the declared command again. Other MCP servers and client settings stay
# unchanged. An unavailable client is skipped, but a failed registration stops
# the installer.
#
# The installer runs this file with one platform argument:
#   mac    Configure clients installed on macOS.
#   linux  Configure clients installed on Linux.
configure_mcp_servers() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

# Register one stdio MCP server with all supported clients.
#
# Arguments:
#   $1    Stable server name owned by dotfiles.
#   $2... Executable and arguments that start the MCP server.
#
# Codex stores global MCP configuration in ~/.codex/config.toml. Claude Code
# stores user-scoped MCP configuration in ~/.claude.json. Their native CLIs
# update only the named server, so this function does not parse or rewrite
# either client format.
_register() {
  local name="$1"
  shift

  if has codex; then
    # Removal makes the final definition deterministic. A missing definition is
    # the normal first-run state, so its removal failure is safe to ignore.
    silent codex mcp remove "$name" || true
    # Keep add output visible. A configuration or command error must stop setup.
    codex mcp add "$name" -- "$@"
  else
    log "Codex CLI is unavailable; skipping its $name MCP registration."
  fi

  if has claude; then
    # User scope makes this server available in every Claude Code project.
    silent claude mcp remove --scope user "$name" || true
    # The separator passes the remaining arguments to the stdio server command.
    claude mcp add --scope user "$name" -- "$@"
  else
    log "Claude Code is unavailable; skipping its $name MCP registration."
  fi
}

# Declare the complete set of global MCP servers managed by dotfiles. Keep one
# call per server so additions and removals stay visible in code review.
_configure() {
  _register chrome-devtools npx --yes chrome-devtools-mcp@latest
}

# Both supported platforms use the same client commands and server inventory.
mac() {
  _configure
}

linux() {
  _configure
}

configure_mcp_servers "$1"
