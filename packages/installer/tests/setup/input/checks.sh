#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/test.sh"

for strategy in keyboard pointer remapping touchpad; do
  [[ -f "$INSTALLER_DIR/setup/input/$strategy.sh" ]] ||
    fail "input setup is missing: $strategy.sh"
done
expect_file_contains "$INSTALLER_DIR/setup/input/touchpad.sh" \
  'defaults write NSGlobalDomain com.apple.trackpad.scaling -float 3' \
  'Mac touchpad speed setting is missing'
expect_file_contains "$INSTALLER_DIR/setup/input/touchpad.sh" \
  "log 'Xfce touchpad changes are not part of this install.'" \
  'Linux touchpad setup must remain an explicit skip'

printf 'Input setup checks passed.\n'
