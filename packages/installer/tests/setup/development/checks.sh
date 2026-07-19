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

printf 'Development setup checks passed.\n'
