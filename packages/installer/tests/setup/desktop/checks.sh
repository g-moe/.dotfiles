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
  "'%b %d  %H:%M:%S'" \
  '+restart' \
  'xfce4-genmon-plugin' \
  '/usr/local/bin/xfce-system-stats' \
  'thunar.desktop' \
  'xfce4-terminal.desktop' \
  'codium.desktop'; do
  expect_file_contains "$top_bar" "$text" "top-bar setup is missing: $text"
done
[[ -f "$INSTALLER_DIR/config/xfce/panel.css" ]] || fail 'Xfce panel CSS is missing'
genmon_command_line="$(grep -n 'Command=/usr/local/bin/xfce-system-stats' "$top_bar" | head -n 1 | cut -d: -f1)"
plugin_list_line="$(grep -n '/panels/panel-1/plugin-ids' "$top_bar" | tail -n 1 | cut -d: -f1)"
[[ -n "$genmon_command_line" && -n "$plugin_list_line" && \
  "$genmon_command_line" -lt "$plugin_list_line" ]] ||
  fail 'Generic Monitor settings must exist before the panel starts the plugin'
for text in 'genmon-15.rc' 'UseLabel=0' 'UpdatePeriod=2000'; do
  expect_file_contains "$top_bar" "$text" "Generic Monitor 4.1 configuration is missing: $text"
done
expect_file_contains "$top_bar" "pgrep -f '/plugins/libgenmon[.]so 15 '" \
  'Generic Monitor must stop before its RC file is replaced'
expect_file_contains "$top_bar" '1 11 12 13 14 3 10 5 15 7 6 9 8' \
  'machine name must appear before system stats'
expect_file_contains "$top_bar" "'Inter SemiBold 10'" \
  'the panel clock must use the UI font'
stats="$INSTALLER_DIR/config/xfce/system-stats.sh"
for text in '/proc/stat' 'MemAvailable:' 'timeout 1 nvidia-smi' 'gpu_busy_percent' "'--prompt'" '<txtclick>xfce4-taskmanager</txtclick>'; do
  expect_file_contains "$stats" "$text" "system stats are missing: $text"
done
expect_file_contains "$ROOT_DIR/packages/theming/create/apps/oh-my-zsh.ts" \
  '/usr/local/bin/xfce-system-stats --prompt' \
  'the Linux prompt must reuse the Xfce system stats collector'
expect_file_contains "$stats" 'size="medium">%s  %s  %s</span>' \
  'system stat values must be larger than their labels'
expect_file_contains "$INSTALLER_DIR/config/xfce/panel.css" \
  '@define-color rice_panel #111817' 'Xfce panel must use the rice near-black'

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
