#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/test.sh"

expect_file_contains "$INSTALLER_DIR/setup/development/node.sh" \
  'mkdir -p "$HOME/.nvm"' 'Node setup must create the fixed NVM directory'

for cli in aws-cli cloudflare; do
  [[ -f "$INSTALLER_DIR/setup/development/$cli.sh" ]] ||
    fail "development CLI setup is missing: $cli.sh"
done
expect_file_contains "$INSTALLER_DIR/setup/development/aws-cli.sh" \
  'brew_formula awscli' 'AWS CLI must use Homebrew on Mac'
expect_file_contains "$INSTALLER_DIR/setup/development/aws-cli.sh" \
  'apt_install awscli' 'AWS CLI must use APT on Linux'
expect_file_contains "$INSTALLER_DIR/setup/development/cloudflare.sh" \
  'brew_formula cloudflared' 'Cloudflare must install cloudflared on Mac'
expect_file_contains "$INSTALLER_DIR/setup/development/cloudflare.sh" \
  'apt_install cloudflared' 'Cloudflare must install cloudflared on Linux'
expect_file_contains "$INSTALLER_DIR/setup/development/cloudflare.sh" \
  'npm install --global wrangler@latest' 'Cloudflare must install Wrangler'

mcp_strategy="$INSTALLER_DIR/setup/development/mcp-servers.sh"
expect_file_contains "$mcp_strategy" \
  'codex mcp add "$name" -- "$@"' \
  'MCP setup must use the Codex CLI'
expect_file_contains "$mcp_strategy" \
  'claude mcp add --scope user "$name" -- "$@"' \
  'MCP setup must use the Claude Code user scope'
expect_file_contains "$mcp_strategy" \
  '_register chrome-devtools npx --yes chrome-devtools-mcp@latest' \
  'MCP setup must declare chrome-devtools through the shared registration helper'
codex_line="$(grep -n "development/codex.sh" "$INSTALLER_DIR/install.sh" | cut -d: -f1)"
mcp_line="$(grep -n "development/mcp-servers.sh" "$INSTALLER_DIR/install.sh" | cut -d: -f1)"
[[ "$mcp_line" -gt "$codex_line" ]] ||
  fail 'MCP setup must run after Codex links its configuration'

printf 'Development setup checks passed.\n'
