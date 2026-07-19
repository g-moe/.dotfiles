#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/test.sh"

dock="$INSTALLER_DIR/setup/desktop/dock.sh"
if grep -Eqi 'plank|dockitem|dconf' "$dock"; then
  fail 'Linux dock setup must not configure Plank'
fi
finder_line="$(grep -n "_mac_app '/System/Library/CoreServices/Finder.app'" "$dock" | cut -d: -f1)"
apps_line="$(grep -n "_mac_app '/System/Applications/Apps.app'" "$dock" | cut -d: -f1)"
[[ -n "$finder_line" && -n "$apps_line" && "$apps_line" -eq $((finder_line + 1)) ]] ||
  fail 'Apps.app must immediately follow Finder in the Dock'
expect_file_contains "$dock" 'xfconf_set_array xfce4-panel /panels int' \
  'lower Xfce panel must be removed through Xfce settings'

top_bar="$INSTALLER_DIR/setup/desktop/top-bar.sh"
for text in \
  '/usr/local/share/icons/tux.svg' \
  "'%b %d  %H:%M'" \
  '+restart' \
  'thunar.desktop' \
  'xfce4-terminal.desktop' \
  'codium.desktop'; do
  expect_file_contains "$top_bar" "$text" "top-bar setup is missing: $text"
done
[[ -f "$INSTALLER_DIR/config/xfce/panel.css" ]] || fail 'Xfce panel CSS is missing'

windows="$INSTALLER_DIR/setup/desktop/windows.sh"
for text in \
  "ask_choice 'Window management' Skip Disable Enable" \
  "ask_choice 'Window configuration' 'Center + Fill'" \
  "0) configuration='center-fill'" \
  'BEGIN dotfiles installer: window management' \
  'com.dotfiles.window-management.hammerspoon.plist' \
  'mac_hammerspoon_has_other_configuration' \
  'open -g "$hammerspoon_app"' \
  'retry 20 0.5 mac_hammerspoon_app' \
  'retry 20 0.5 silent open -g "$hammerspoon_app"' \
  'retry 40 0.25 pgrep -x Hammerspoon'; do
  expect_file_contains "$windows" "$text" "window setup is missing: $text"
done

center_fill="$INSTALLER_DIR/config/window-management/center-fill.lua"
for text in \
  'hs.window.animationDuration = 0' \
  'win:isMaximizable() == true' \
  'local gap = 16' \
  'local frame = win:screen():frame()' \
  'w = frame.w - gap * 2' \
  'h = frame.h - gap * 2' \
  'win:centerOnScreen(nil, true, 0)' \
  'centerFillWindowWatcher:getWindows()'; do
  expect_file_contains "$center_fill" "$text" "Center + Fill is missing: $text"
done
for event in windowCreated windowFocused windowUnminimized; do
  expect_file_contains "$center_fill" "hs.window.filter.$event" \
    "Center + Fill does not handle $event"
done

expect_file_contains "$INSTALLER_DIR/setup/desktop/machine-name.sh" \
  'silent launchctl print "$service"' 'machine-name setup must wait for launchd'

printf 'Desktop setup checks passed.\n'
