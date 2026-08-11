#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/test.sh"

# Exercise the MCP strategy with fake client executables. The test records CLI
# arguments in a temporary log and never reads or changes real user settings.
strategy="$INSTALLER_DIR/setup/development/mcp-servers.sh"
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
# Only add fails. Remove must still complete before the simulated failure.
if [[ "${MCP_TEST_FAIL_ADD:-0}" == 1 && "${1:-} ${2:-}" == 'mcp add' ]]; then
  exit 1
fi
SCRIPT
  chmod +x "$directory/$client"
}

clients="$temporary_dir/clients"
commands="$temporary_dir/commands.log"
make_client codex "$clients"
make_client claude "$clients"

# Two identical runs verify command order and repeatable registration behavior.
for _ in 1 2; do
  MCP_TEST_LOG="$commands" PATH="$clients:/usr/bin:/bin" bash "$strategy" mac
done

# The expected log also proves that both clients receive the same stdio command
# and that Claude Code always uses global user scope.
expected="$temporary_dir/expected.log"
for _ in 1 2; do
  printf '%s\n' \
    'codex <mcp> <remove> <chrome-devtools>' \
    'codex <mcp> <add> <chrome-devtools> <--> <npx> <--yes> <chrome-devtools-mcp@latest>' \
    'claude <mcp> <remove> <--scope> <user> <chrome-devtools>' \
    'claude <mcp> <add> <--scope> <user> <chrome-devtools> <--> <npx> <--yes> <chrome-devtools-mcp@latest>' \
    >>"$expected"
done
cmp -s "$expected" "$commands" || {
  diff -u "$expected" "$commands" >&2 || true
  fail 'MCP registration commands are incorrect or not repeatable'
}

# Remove Claude Code from PATH to verify that one unavailable client does not
# prevent the available client from receiving its registration.
codex_only="$temporary_dir/codex-only"
make_client codex "$codex_only"
skip_output="$(MCP_TEST_LOG="$temporary_dir/codex-only.log" \
  PATH="$codex_only:/usr/bin:/bin" bash "$strategy" linux)"
grep -Fq 'Claude Code is unavailable' <<<"$skip_output" ||
  fail 'a missing Claude Code CLI must be reported and skipped'

# An add failure is material. It must leave the strategy with a nonzero status
# so the parent installer reports the failed MCP setup step.
if MCP_TEST_FAIL_ADD=1 MCP_TEST_LOG="$temporary_dir/failure.log" \
  PATH="$clients:/usr/bin:/bin" bash "$strategy" mac >/dev/null 2>&1; then
  fail 'a failed MCP registration must fail the strategy'
fi

printf 'MCP server setup checks passed.\n'
