#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/test.sh"

agents="$INSTALLER_DIR/setup/agents.sh"
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
  "safe_symlink_group 'Agent skills'" \
  'Agents setup must link shared skills'
for target_root in \
  '$HOME/.agents/skills' \
  '$HOME/.codex/skills' \
  '$HOME/.claude/skills' \
  '$HOME/.cursor/skills' \
  '$HOME/.config/opencode/skills'; do
  expect_file_contains "$agents" "\"$target_root\"" \
    "Agents setup must link skills for $target_root"
done

printf 'Agents setup checks passed.\n'
