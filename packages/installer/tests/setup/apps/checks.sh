#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/test.sh"

expect_file_contains "$INSTALLER_DIR/setup/apps/nordvpn.sh" \
  "ask_binary 'Install NordVPN?' n" 'NordVPN prompt must default to no'
expect_file_contains "$INSTALLER_DIR/setup/apps/chrome.sh" \
  'brew_cask google-chrome arc' 'Mac must install Chrome and Arc'
expect_file_contains "$INSTALLER_DIR/setup/apps/docker.sh" \
  'https://download.docker.com/linux/debian' 'Docker must use its Debian repository'
expect_file_contains "$INSTALLER_DIR/setup/apps/tailscale.sh" \
  'stable/debian/${LINUX_CODENAME}' 'Tailscale must use its Debian repository'
expect_file_contains "$INSTALLER_DIR/setup/apps/prepare.sh" \
  'brew_formula jq' 'Mac preparation must install jq before retiring packages'

retire_file="$INSTALLER_DIR/packages/retire.json"
retire_schema="$INSTALLER_DIR/packages/retire.schema.json"
jq empty "$retire_file" "$retire_schema" || fail 'retire JSON files must parse'
expect_file_contains "$INSTALLER_DIR/setup/apps/retire.sh" \
  'validate_retire_file "$RETIRE_FILE"' 'retire setup must validate before uninstalling'

monitor="$INSTALLER_DIR/setup/apps/system-monitor.sh"
for text in \
  'extract_github_source_archive g-moe/mactop "$commit" "$checksum"' \
  "local commit='e688d5778035b6d3eb30f2a8c8083cb1d429723d'" \
  'install -m 0755 "$build_dir/mactop" "$binary_path"' \
  'safe_symlink_group mactop' \
  'launchctl bootstrap "$domain" "$agent_path"'; do
  expect_file_contains "$monitor" "$text" "system monitor setup is missing: $text"
done
if grep -R -Fq 'brew_cask macs-fan-control' "$INSTALLER_DIR/setup"; then
  fail 'Mac must use mactop instead of Macs Fan Control'
fi
expect_file_contains "$ROOT_DIR/mactop/com.dotfiles.mactop-menubar.plist" \
  '<string>/usr/bin/script</string>' 'mactop startup must provide a tty'

terminal="$INSTALLER_DIR/setup/apps/terminal.sh"
expect_file_contains "$terminal" 'xfconf_set xfce4-terminal /font-name' \
  'Linux terminal must use Xfce live settings'
expect_file_contains "$terminal" 'xfconf_set xfce4-terminal /misc-borders-default bool true' \
  'Xfce Terminal must keep window borders'
if grep -Eqi 'ghostty|kitty|alacritty' <(sed -n '/^linux()/,/^}/p' "$terminal"); then
  fail 'Linux terminal setup must not install another terminal'
fi

printf 'App setup checks passed.\n'
