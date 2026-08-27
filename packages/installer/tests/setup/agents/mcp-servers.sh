#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/test.sh"

# Exercise the MCP strategy with fake client executables and an isolated home.
strategy="$INSTALLER_DIR/setup/agents/mcp-servers.sh"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT

# Create a fake Codex or Claude Code executable.
#
# Arguments:
#   $1 Client command name to create.
#   $2 Directory that receives the executable.
#
# Each fake records its complete argument list. MCP_TEST_FAIL_ADD can also make
# an add operation fail so the test can verify installer error propagation.
make_client() {
  local client="$1"
  local directory="$2"

  mkdir -p "$directory"
  sed "s/CLIENT/$client/" >"$directory/$client" <<'SCRIPT'
#!/usr/bin/env bash
# Use angle brackets to keep empty strings and option boundaries visible.
printf 'CLIENT' >>"$MCP_TEST_LOG"
printf ' <%s>' "$@" >>"$MCP_TEST_LOG"
printf '\n' >>"$MCP_TEST_LOG"
# Simulate Claude changing its config during remove, then failing during add.
if [[ 'CLIENT' == claude && "${1:-} ${2:-}" == 'mcp remove' && \
  -n "${MCP_TEST_CLAUDE_CONFIG:-}" ]]; then
  printf '{"changed":true}\n' >"$MCP_TEST_CLAUDE_CONFIG"
fi
if [[ 'CLIENT' == claude && "${MCP_TEST_FAIL_ADD:-0}" == 1 && \
  "${1:-} ${2:-}" == 'mcp add' ]]; then
  exit 1
fi
SCRIPT
  chmod +x "$directory/$client"
}

clients="$temporary_dir/clients"
commands="$temporary_dir/commands.log"
node_path="$(command -v node)"
node_dir="$(dirname "$node_path")"
global_node_modules="$temporary_dir/global/lib/node_modules"
entrypoint="$global_node_modules/chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js"
chrome_path='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
mkdir -p "$(dirname "$entrypoint")"
touch "$entrypoint"
make_client codex "$clients"
make_client claude "$clients"

# npm is isolated so the test proves the pinned global install and path lookup
# without changing the machine's real global packages.
cat >"$clients/npm" <<'SCRIPT'
#!/usr/bin/env bash
case "$1" in
  install)
    shift
    [[ "$*" == '--global chrome-devtools-mcp@1.8.0' ]] || exit 1
    ;;
  root)
    printf '%s\n' "$MCP_TEST_NPM_ROOT"
    ;;
  *) exit 1 ;;
esac
SCRIPT
chmod +x "$clients/npm"

# Command parity: every client receives one identical command, and a rerun
# converges on the same result.
for _ in 1 2; do
  HOME="$temporary_dir/home" MCP_TEST_LOG="$commands" \
    MCP_TEST_NPM_ROOT="$global_node_modules" \
    PATH="$clients:$node_dir:/usr/bin:/bin" bash "$strategy" mac
done

# The expected log also proves that both clients receive the same stdio command
# and that Claude Code always uses global user scope.
expected="$temporary_dir/expected.log"
for _ in 1 2; do
  printf '%s\n' \
    "codex <mcp> <add> <chrome-devtools> <--> <$node_path> <$entrypoint> <--headless> <--isolated> <--executablePath> <$chrome_path>" \
    'claude <mcp> <remove> <--scope> <user> <chrome-devtools>' \
    "claude <mcp> <add> <--scope> <user> <chrome-devtools> <--> <$node_path> <$entrypoint> <--headless> <--isolated> <--executablePath> <$chrome_path>" \
    >>"$expected"
done
cmp -s "$expected" "$commands" || {
  diff -u "$expected" "$commands" >&2 || true
  fail 'MCP registration commands are incorrect or not repeatable'
}

# Cursor preservation: keep unrelated root settings and MCP servers.
cursor_config="$temporary_dir/home/.cursor/mcp.json"
jq -e '
  .mcpServers["chrome-devtools"] == {
    command: $node,
    args: [$entrypoint, "--headless", "--isolated", "--executablePath", $chrome]
  }
' --arg node "$node_path" --arg entrypoint "$entrypoint" --arg chrome "$chrome_path" \
  "$cursor_config" >/dev/null || fail 'Cursor MCP configuration is incorrect'
jq '.theme = "dark" | .mcpServers.personal = {url: "https://example.com/mcp"}' \
  "$cursor_config" >"$temporary_dir/cursor-with-personal.json"
mv "$temporary_dir/cursor-with-personal.json" "$cursor_config"
HOME="$temporary_dir/home" MCP_TEST_LOG="$temporary_dir/third-run.log" \
  MCP_TEST_NPM_ROOT="$global_node_modules" \
  PATH="$clients:$node_dir:/usr/bin:/bin" bash "$strategy" mac
jq -e '.mcpServers.personal.url == "https://example.com/mcp"' \
  "$cursor_config" >/dev/null || fail 'Cursor MCP generation removed user data'
jq -e '.theme == "dark"' "$cursor_config" >/dev/null ||
  fail 'Cursor MCP generation removed an unrelated root setting'

# Keep a user-managed Cursor symlink intact while updating its target.
mv "$cursor_config" "$temporary_dir/cursor-target.json"
ln -s "$temporary_dir/cursor-target.json" "$cursor_config"
HOME="$temporary_dir/home" MCP_TEST_LOG="$temporary_dir/symlink-run.log" \
  MCP_TEST_NPM_ROOT="$global_node_modules" \
  PATH="$clients:$node_dir:/usr/bin:/bin" bash "$strategy" mac
[[ -L "$cursor_config" ]] || fail 'Cursor MCP generation replaced its configuration symlink'

# Cursor preflight: malformed shapes fail before Codex or Claude can change.
invalid_index=0
for invalid_config in '[]' 'null' '{"mcpServers":[]}' '{"mcpServers":null}'; do
  invalid_index=$((invalid_index + 1))
  invalid_home="$temporary_dir/invalid-$invalid_index"
  mkdir -p "$invalid_home/.cursor"
  printf '%s\n' "$invalid_config" >"$invalid_home/.cursor/mcp.json"
  cp "$invalid_home/.cursor/mcp.json" "$invalid_home/original.json"
  if HOME="$invalid_home" MCP_TEST_LOG="$invalid_home/commands.log" \
    MCP_TEST_NPM_ROOT="$global_node_modules" \
    PATH="$clients:$node_dir:/usr/bin:/bin" bash "$strategy" mac \
    >/dev/null 2>&1; then
    fail 'invalid Cursor MCP configuration must stop setup'
  fi
  [[ ! -e "$invalid_home/commands.log" ]] ||
    fail 'Cursor preflight must run before native client changes'
  cmp -s "$invalid_home/original.json" "$invalid_home/.cursor/mcp.json" ||
    fail 'Cursor preflight failure changed the original configuration'
done

# Remove Claude Code from PATH to verify that one unavailable client does not
# prevent the available client from receiving its registration.
codex_only="$temporary_dir/codex-only"
make_client codex "$codex_only"
cp "$clients/npm" "$codex_only/npm"
skip_output="$(MCP_TEST_LOG="$temporary_dir/codex-only.log" \
  MCP_TEST_NPM_ROOT="$global_node_modules" \
  HOME="$temporary_dir/codex-only-home" \
  PATH="$codex_only:$node_dir:/usr/bin:/bin" \
  bash "$strategy" mac)"
grep -Fq 'Claude Code is unavailable' <<<"$skip_output" ||
  fail 'a missing Claude Code CLI must be reported and skipped'

# Claude rollback: restore the complete original user config when add fails
# after the required remove operation.
failure_home="$temporary_dir/failure-home"
mkdir -p "$failure_home"
printf '{"original":true}\n' >"$failure_home/.claude.json"
cp "$failure_home/.claude.json" "$failure_home/expected.json"
if MCP_TEST_FAIL_ADD=1 MCP_TEST_LOG="$temporary_dir/failure.log" \
  MCP_TEST_NPM_ROOT="$global_node_modules" \
  MCP_TEST_CLAUDE_CONFIG="$failure_home/.claude.json" HOME="$failure_home" \
  PATH="$clients:$node_dir:/usr/bin:/bin" \
  bash "$strategy" mac >/dev/null 2>&1; then
  fail 'a failed MCP registration must fail the strategy'
fi
cmp -s "$failure_home/expected.json" "$failure_home/.claude.json" ||
  fail 'Claude MCP failure did not restore the original user config'

printf 'MCP server setup checks passed.\n'
