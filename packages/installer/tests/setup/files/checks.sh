#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/test.sh"

preferences="$INSTALLER_DIR/setup/files/preferences.sh"
expect_file_contains "$preferences" \
  'defaults write com.apple.finder AppleShowAllFiles -bool true' \
  'Finder must always show hidden files'
expect_file_contains "$preferences" \
  'xfconf_set thunar /last-show-hidden bool true' \
  'Thunar must always show hidden files'

sidebar="$INSTALLER_DIR/setup/files/sidebar.sh"
helper="$INSTALLER_DIR/setup/files/finder-sidebar.js"
[[ -f "$helper" ]] || fail 'Finder sidebar helper is missing'
for text in \
  'finder-sidebar.js' \
  'Privacy_AllFiles' \
  '"$HOME" "$ROOT_DIR" "$HOME/code"' \
  'file://$ROOT_DIR .dotfiles'; do
  expect_file_contains "$sidebar" "$text" "sidebar setup is missing: $text"
done
expect_file_contains "$helper" 'NSKeyedArchiver.archivedDataWithRootObject' \
  'Finder sidebar helper must write favorites'
if grep -Fq 'leaving the sidebar unchanged' "$sidebar"; then
  fail 'sidebar setup must not preserve the old .config favorite'
fi

printf 'File setup checks passed.\n'
