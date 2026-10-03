#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/test.sh"

expect_file_contains "$INSTALLER_DIR/setup/development/node.sh" \
  'mkdir -p "$HOME/.nvm"' 'Node setup must create the fixed NVM directory'
expect_file_contains "$ROOT_DIR/zsh/.zshrc" \
  "alias files='spf'" 'Zsh must provide the Superfile alias'

development_body="$(sed -n '/^install_development() {/,/^}/p' "$INSTALLER_DIR/install.sh")"
if grep -Fq 'install_agents' <<<"$development_body"; then
  fail 'Development setup must not install agent configuration'
fi

pi="$INSTALLER_DIR/setup/development/pi.sh"
expect_file_contains "$pi" \
  'npm install -g --ignore-scripts --min-release-age=0 --prefix "$HOME/.local"' \
  'Pi must use its non-interactive npm install command'
expect_file_contains "$pi" '@earendil-works/pi-coding-agent' \
  'Pi must install the official package'
expect_file_contains "$pi" '[[ -x "$HOME/.local/bin/pi" ]] && return 0' \
  'Pi must check its stable executable before installation'
for platform in mac linux; do
  platform_body="$(sed -n "/^${platform}() {/,/^}/p" "$pi")"
  grep -Fq '_install' <<<"$platform_body" ||
    fail "$platform must use the shared Pi installation path"
done
node_line="$(grep -n "development/node.sh" "$INSTALLER_DIR/install.sh" | cut -d: -f1)"
pi_line="$(grep -n "development/pi.sh" "$INSTALLER_DIR/install.sh" | cut -d: -f1)"
[[ "$pi_line" -gt "$node_line" ]] ||
  fail 'Pi setup must run after Node.js setup'

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

zed="$INSTALLER_DIR/setup/development/zed-settings.sh"
expect_file_contains "$zed" "safe_symlink_group 'Zed settings'" \
  'Zed must use the same grouped per-file linking helper as VSCodium'
expect_file_contains "$zed" '"$ROOT_DIR/zed/user/settings.json" "$HOME/.config/zed/settings.json"' \
  'Zed settings must link from the application config folder'
expect_file_contains "$zed" '"$ROOT_DIR/zed/user/keymap.json" "$HOME/.config/zed/keymap.json"' \
  'Zed keymap must link from the application config folder'
expect_file_contains "$INSTALLER_DIR/install.sh" "--zed) printf 'zed" \
  'The installer must offer a Zed-only settings mode'

printf 'Development setup checks passed.\n'
