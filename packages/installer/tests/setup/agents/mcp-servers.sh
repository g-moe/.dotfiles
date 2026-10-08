#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/test.sh"

# Exercise the MCP strategy with fake client executables and an isolated home.
strategy="$INSTALLER_DIR/setup/agents/mcp-servers.sh"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT

# Create a fake native client executable.
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
if [[ 'CLIENT' == pi && "${MCP_TEST_FAIL_PI_ADD:-0}" == 1 && \
  "${1:-} ${2:-}" == 'mcp add' ]]; then
  exit 1
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
make_client pi "$clients"

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

# Every strategy run uses the same isolated npm package and command paths.
run_strategy() {
  local fixture_home="$1"
  local fixture_log="$2"
  local fixture_clients="${3:-$clients}"

  env -u OPENCODE_CONFIG -u OPENCODE_CONFIG_DIR -u OPENCODE_CONFIG_CONTENT -u XDG_CONFIG_HOME \
    HOME="$fixture_home" MCP_TEST_LOG="$fixture_log" MCP_TEST_NPM_ROOT="$global_node_modules" \
    PATH="$fixture_clients:$node_dir:/usr/bin:/bin" bash "$strategy" mac
}

# Command parity: every client receives one identical command, and a rerun
# converges on the same result.
for _ in 1 2; do
  run_strategy "$temporary_dir/home" "$commands"
done

# The expected log also proves that native clients receive the same command
# and that Claude Code always uses global user scope.
expected="$temporary_dir/expected.log"
for _ in 1 2; do
  printf '%s\n' \
    "codex <mcp> <add> <chrome-devtools> <--> <$node_path> <$entrypoint> <--headless> <--isolated> <--executablePath> <$chrome_path>" \
    'claude <mcp> <remove> <--scope> <user> <chrome-devtools>' \
    "claude <mcp> <add> <--scope> <user> <chrome-devtools> <--> <$node_path> <$entrypoint> <--headless> <--isolated> <--executablePath> <$chrome_path>" \
    "pi <mcp> <add> <chrome-devtools> <--> <$node_path> <$entrypoint> <--headless> <--isolated> <--executablePath> <$chrome_path>" \
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
run_strategy "$temporary_dir/home" "$temporary_dir/third-run.log"
jq -e '.mcpServers.personal.url == "https://example.com/mcp"' \
  "$cursor_config" >/dev/null || fail 'Cursor MCP generation removed user data'
jq -e '.theme == "dark"' "$cursor_config" >/dev/null ||
  fail 'Cursor MCP generation removed an unrelated root setting'

# Keep a user-managed Cursor symlink intact while updating its target.
mv "$cursor_config" "$temporary_dir/cursor-target.json"
ln -s "$temporary_dir/cursor-target.json" "$cursor_config"
run_strategy "$temporary_dir/home" "$temporary_dir/symlink-run.log"
[[ -L "$cursor_config" ]] || fail 'Cursor MCP generation replaced its configuration symlink'

# Cursor preflight: malformed shapes fail before Codex or Claude can change.
invalid_index=0
for invalid_config in '[]' 'null' '{"mcpServers":[]}' '{"mcpServers":null}'; do
  invalid_index=$((invalid_index + 1))
  invalid_home="$temporary_dir/invalid-$invalid_index"
  mkdir -p "$invalid_home/.cursor"
  printf '%s\n' "$invalid_config" >"$invalid_home/.cursor/mcp.json"
  cp "$invalid_home/.cursor/mcp.json" "$invalid_home/original.json"
  if run_strategy "$invalid_home" "$invalid_home/commands.log" >/dev/null 2>&1; then
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
skip_output="$(run_strategy "$temporary_dir/codex-only-home" "$temporary_dir/codex-only.log" "$codex_only")"
grep -Fq 'Claude Code is unavailable' <<<"$skip_output" ||
  fail 'a missing Claude Code CLI must be reported and skipped'

# Claude rollback: restore the complete original user config when add fails
# after the required remove operation.
failure_home="$temporary_dir/failure-home"
mkdir -p "$failure_home"
printf '{"original":true}\n' >"$failure_home/.claude.json"
cp "$failure_home/.claude.json" "$failure_home/expected.json"
if MCP_TEST_FAIL_ADD=1 MCP_TEST_CLAUDE_CONFIG="$failure_home/.claude.json" \
  run_strategy "$failure_home" "$temporary_dir/failure.log" >/dev/null 2>&1; then
  fail 'a failed MCP registration must fail the strategy'
fi
cmp -s "$failure_home/expected.json" "$failure_home/.claude.json" ||
  fail 'Claude MCP failure did not restore the original user config'

# OpenCode receives the same command, including the Node executable.
opencode_config="$temporary_dir/home/.config/opencode/opencode.json"
jq -e '.mcp["chrome-devtools"] == {
  type: "local",
  command: [$node, $entrypoint, "--headless", "--isolated", "--executablePath", $chrome],
  enabled: true
}' --arg node "$node_path" --arg entrypoint "$entrypoint" --arg chrome "$chrome_path" \
  "$opencode_config" >/dev/null || fail 'OpenCode MCP command is incorrect'

# Update JSONC without removing comments, unrelated settings, servers, or links.
adapter="$INSTALLER_DIR/setup/agents/mcp-opencode.mjs"
config_directory="$temporary_dir/opencode-custom"
mkdir -p "$config_directory"
cat >"$config_directory/opencode.jsonc" <<'JSONC'
{
  // Keep this user comment.
  "model": "personal/model",
  "mcp": {
    "personal": {"type": "remote", "url": "https://example.com/mcp"},
  },
}
JSONC
printf '{"model":"lower-priority"}\n' >"$config_directory/opencode.json"
for _ in 1 2; do
  OPENCODE_CONFIG_DIR="$config_directory" node "$adapter" merge chrome-devtools node server.js
done
expect_file_contains "$config_directory/opencode.jsonc" '// Keep this user comment.' \
  'OpenCode merge must preserve comments'
node --input-type=module - "$config_directory/opencode.jsonc" <<'JS'
import fs from "node:fs";
import assert from "node:assert/strict";
import { parse } from "jsonc-parser";
const config = parse(fs.readFileSync(process.argv[2], "utf8"));
assert.equal(config.model, "personal/model");
assert.equal(config.mcp.personal.url, "https://example.com/mcp");
assert.deepEqual(config.mcp["chrome-devtools"].command, ["node", "server.js"]);
JS
mv "$config_directory/opencode.jsonc" "$temporary_dir/opencode-target.jsonc"
ln -s "$temporary_dir/opencode-target.jsonc" "$config_directory/opencode.jsonc"
OPENCODE_CONFIG_DIR="$config_directory" node "$adapter" merge chrome-devtools node newer.js
[[ -L "$config_directory/opencode.jsonc" ]] || fail 'OpenCode merge replaced its symlink'
expect_file_contains "$temporary_dir/opencode-target.jsonc" 'newer.js' \
  'OpenCode merge must update the symlink target'

# Respect the global XDG directory and an explicit configuration file.
XDG_CONFIG_HOME="$temporary_dir/xdg" node "$adapter" merge chrome-devtools node server.js
[[ -f "$temporary_dir/xdg/opencode/opencode.json" ]] || fail 'OpenCode must respect XDG_CONFIG_HOME'
OPENCODE_CONFIG="$temporary_dir/explicit.jsonc" \
  node "$adapter" merge chrome-devtools node explicit.js
expect_file_contains "$temporary_dir/explicit.jsonc" 'explicit.js' \
  'OpenCode must respect OPENCODE_CONFIG'

# A directory loads after the explicit file. Update it when both overrides exist.
cp "$temporary_dir/explicit.jsonc" "$temporary_dir/explicit-original.jsonc"
OPENCODE_CONFIG="$temporary_dir/explicit.jsonc" OPENCODE_CONFIG_DIR="$config_directory" \
  node "$adapter" merge chrome-devtools node directory-wins.js
expect_file_contains "$config_directory/opencode.jsonc" 'directory-wins.js' \
  'OpenCode custom directory must override its explicit file'
cmp -s "$temporary_dir/explicit-original.jsonc" "$temporary_dir/explicit.jsonc" || \
  fail 'OpenCode must not update the lower-priority explicit file'

# Add the managed entry without rewriting inherited legacy settings.
legacy_root="$temporary_dir/legacy-root"
mkdir -p "$legacy_root/opencode"
printf '{"model":"personal/model"}\n' >"$legacy_root/opencode/config.json"
cp "$legacy_root/opencode/config.json" "$temporary_dir/legacy-original.json"
XDG_CONFIG_HOME="$legacy_root" node "$adapter" merge chrome-devtools node server.js
cmp -s "$temporary_dir/legacy-original.json" "$legacy_root/opencode/config.json" || \
  fail 'OpenCode setup must preserve inherited legacy settings'
jq -e '.mcp["chrome-devtools"].command == ["node", "server.js"]' \
  "$legacy_root/opencode/opencode.json" >/dev/null || fail 'OpenCode managed entry is absent'

# Invalid OpenCode input must fail before any native client can change.
invalid_index=0
for invalid_config in '[]' 'null' '{"mcp":[]}' '{"mcp":null}' '{bad JSON'; do
  invalid_index=$((invalid_index + 1))
  invalid_home="$temporary_dir/opencode-invalid-$invalid_index"
  mkdir -p "$invalid_home/.config/opencode"
  printf '%s\n' "$invalid_config" >"$invalid_home/.config/opencode/opencode.jsonc"
  cp "$invalid_home/.config/opencode/opencode.jsonc" "$invalid_home/original.jsonc"
  if run_strategy "$invalid_home" "$invalid_home/commands.log" >/dev/null 2>&1; then
    fail 'Invalid OpenCode configuration must stop setup'
  fi
  [[ ! -e "$invalid_home/commands.log" ]] || fail 'OpenCode preflight must precede native writes'
  cmp -s "$invalid_home/original.jsonc" "$invalid_home/.config/opencode/opencode.jsonc" || \
    fail 'OpenCode preflight changed invalid user data'
done

grep -Fq 'Pi CLI is unavailable' <<<"$skip_output" || \
  fail 'A missing Pi CLI must be reported and skipped'

# Keep a broken user link intact and expose the failure.
broken_directory="$temporary_dir/opencode-broken"
mkdir -p "$broken_directory"
ln -s "$temporary_dir/missing-target.jsonc" "$broken_directory/opencode.jsonc"
if OPENCODE_CONFIG_DIR="$broken_directory" node "$adapter" merge chrome-devtools node server.js \
  >/dev/null 2>&1; then
  fail 'A broken OpenCode configuration link must fail'
fi
[[ -L "$broken_directory/opencode.jsonc" ]] || fail 'OpenCode replaced a broken user link'

# A native Pi error must remain visible as a strategy failure.
if MCP_TEST_FAIL_PI_ADD=1 run_strategy "$temporary_dir/pi-failure" "$temporary_dir/pi-failure.log" \
  >/dev/null 2>&1; then
  fail 'A failed Pi MCP registration must fail setup'
fi

printf 'MCP server setup checks passed.\n'
