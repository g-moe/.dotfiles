#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/test.sh"

agents="$INSTALLER_DIR/setup/agents.sh"
skills="$INSTALLER_DIR/setup/agents/skills.sh"
expect_file_contains "$agents" \
  '"$ROOT_DIR/.agents/AGENTS.md" "$HOME/.codex/AGENTS.md"' \
  'Agents setup must link Codex global instructions'
expect_file_contains "$agents" \
  '"$ROOT_DIR/.agents/AGENTS.md" "$HOME/.pi/agent/AGENTS.md"' \
  'Agents setup must link Pi global instructions'
expect_file_contains "$agents" \
  '"$ROOT_DIR/.agents/AGENTS.md" "$HOME/.claude/AGENTS.md"' \
  'Agents setup must link the Claude Code instruction import'
expect_file_contains "$agents" \
  '"$ROOT_DIR/.agents/CLAUDE.md" "$HOME/.claude/CLAUDE.md"' \
  'Agents setup must link Claude Code global instructions'
expect_file_contains "$agents" \
  "safe_symlink_group 'Agent usage CLI'" \
  'Agents setup must install the agent usage CLI'
expect_file_contains "$agents" \
  'packages/agent-usage/tsconfig.json' \
  'Agents setup must build the agent usage package'
expect_file_contains "$agents" \
  'chmod +x "$ROOT_DIR/packages/agent-usage/dist/cli/main.js"' \
  'Agents setup must make the agent usage CLI executable'
for target_root in \
  '$HOME/.agents/skills' \
  '$HOME/.codex/skills' \
  '$HOME/.claude/skills' \
  '$HOME/.cursor/skills'; do
  expect_file_contains "$skills" "\"$target_root\"" \
    "Agents setup must link skills for $target_root"
done

agents_line="$(grep -n "agents.sh" "$INSTALLER_DIR/install.sh" | head -1 | cut -d: -f1)"
skills_line="$(grep -n "agents/skills.sh" "$INSTALLER_DIR/install.sh" | cut -d: -f1)"
mcp_line="$(grep -n "agents/mcp-servers.sh" "$INSTALLER_DIR/install.sh" | cut -d: -f1)"
[[ "$skills_line" -gt "$agents_line" ]] ||
  fail 'Skill setup must run after the shared agent configuration'
[[ "$mcp_line" -gt "$agents_line" ]] ||
  fail 'MCP setup must run after the shared agent configuration'
[[ "$mcp_line" -gt "$skills_line" ]] ||
  fail 'MCP setup must run after skill setup'

printf 'Agents setup checks passed.\n'
