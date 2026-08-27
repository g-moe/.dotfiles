#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

# Register one pinned Chrome DevTools MCP command with every supported client.
# Validate shared inputs before the first write. Each adapter preserves unrelated
# client state. A late failure can leave an earlier client updated; rerunning the
# installer safely converges all clients on the same command.
configure_mcp_servers() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

configure_chrome_devtools() {
  local os="$1"
  local node_path
  local npm_root
  local entrypoint
  local browser_path

  activate_repo_node "$ROOT_DIR" || die 'Node.js is not available.'
  make_codex_available "$os"
  # MCP servers are machine tools, not repository development dependencies.
  # Install one pinned global copy for every client to share.
  npm install --global chrome-devtools-mcp@1.8.0
  node_path="$(command -v node)"
  npm_root="$(npm root --global)"
  entrypoint="$npm_root/chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js"
  browser_path="$(chrome_browser_path "$os")"

  [[ -f "$entrypoint" ]] || die 'Chrome DevTools MCP is not installed.'
  [[ -x "$browser_path" ]] || die "MCP browser is missing: $browser_path"

  # Cursor has no add CLI. Validate its existing JSON before native clients
  # change, so malformed Cursor state cannot cause a partial update.
  node "$STRATEGY_DIR/mcp-cursor.mjs" validate "$HOME/.cursor/mcp.json"

  register_global_server chrome-devtools \
    "$node_path" "$entrypoint" \
    --headless --isolated --executablePath "$browser_path"
}

make_codex_available() {
  local os="$1"
  local bundled_codex='/Applications/ChatGPT.app/Contents/Resources/codex'

  # ChatGPT ships Codex on macOS, but normal terminals do not include its app
  # resources in PATH. Prefer an existing CLI and otherwise expose the bundle.
  if ! has codex && [[ "$os" == mac && -x "$bundled_codex" ]]; then
    PATH="$(dirname "$bundled_codex"):$PATH"
    export PATH
  fi
}

chrome_browser_path() {
  case "$1:${LINUX_ARCH:-}" in
    mac:) printf '%s\n' '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' ;;
    linux:amd64) printf '%s\n' '/usr/bin/google-chrome' ;;
    linux:arm64) printf '%s\n' '/usr/bin/brave-browser' ;;
    *) die "Unsupported MCP platform: $1 ${LINUX_ARCH:-}" ;;
  esac
}

# Send the exact same stdio command to every supported client.
register_global_server() {
  register_codex_server "$@"
  register_claude_server "$@"
  register_cursor_server "$@"
}

register_codex_server() {
  local name="$1"
  shift

  if has codex; then
    # Codex replaces a named server without a remove-first data-loss window.
    codex mcp add "$name" -- "$@"
  else
    log "Codex CLI is unavailable; skipping its $name MCP registration."
  fi
}

# Register one stdio MCP server with Claude Code.
register_claude_server() {
  local name="$1"
  shift
  local config="$HOME/.claude.json"
  local backup
  local had_config=0

  if has claude; then
    # Claude rejects duplicate names. Back up the complete user config so its
    # required remove-then-add sequence behaves as one recoverable update.
    backup="$(mktemp)"
    if [[ -e "$config" ]]; then
      cp -p "$config" "$backup"
      had_config=1
    fi
    silent claude mcp remove --scope user "$name" || true
    if ! claude mcp add --scope user "$name" -- "$@"; then
      if (( had_config )); then
        cp -p "$backup" "$config"
      else
        rm -f "$config"
      fi
      rm -f "$backup"
      return 1
    fi
    rm -f "$backup"
  else
    log "Claude Code is unavailable; skipping its $name MCP registration."
  fi
}

# Merge one stdio MCP server into Cursor's global JSON configuration. Cursor
# does not provide an add command, so update only the named entry and preserve
# all other user settings and servers.
register_cursor_server() {
  local name="$1"
  local command="$2"
  shift 2

  node "$STRATEGY_DIR/mcp-cursor.mjs" merge \
    "$HOME/.cursor/mcp.json" "$name" "$command" "$@"
}

# Keep the standard installer strategy entry points even though both platforms
# share the same process. Browser selection remains inside the shared function.
mac() {
  configure_chrome_devtools mac
}

linux() {
  configure_chrome_devtools linux
}

configure_mcp_servers "$1"
