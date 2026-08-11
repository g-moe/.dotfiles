#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_top_bar() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  defaults -currentHost write com.apple.controlcenter Battery -int 8
  defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -int 0
  defaults -currentHost write com.apple.controlcenter Bluetooth -int 24
  defaults -currentHost write com.apple.controlcenter Display -int 8
  defaults -currentHost write com.apple.controlcenter FocusModes -int 8
  defaults -currentHost write com.apple.controlcenter KeyboardBrightness -int 8
  defaults -currentHost write com.apple.controlcenter NowPlaying -int 8
  defaults -currentHost write com.apple.controlcenter ScreenMirroring -int 8
  defaults -currentHost write com.apple.controlcenter Sound -int 8
  defaults -currentHost write com.apple.controlcenter TimeMachine -int 8
  defaults -currentHost write com.apple.controlcenter VoiceControl -int 8
  defaults -currentHost write com.apple.controlcenter WiFi -int 8
  defaults write com.apple.controlcenter 'NSStatusItem Visible AirDrop' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Battery' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible BentoBox' -bool true
  defaults write com.apple.controlcenter 'NSStatusItem Visible Bluetooth' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible FaceTime' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible FocusModes' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Item-0' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Item-1' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Item-2' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Item-3' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Item-4' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Item-5' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Item-6' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Item-7' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Item-8' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Item-9' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible ScreenMirroring' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Shortcuts' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem Visible Sound' -bool false
  defaults write com.apple.controlcenter 'NSStatusItem VisibleCC BentoBox-0' -bool true
  defaults write com.apple.controlcenter 'NSStatusItem VisibleCC Clock' -bool true
  defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1
  defaults write com.apple.controlcenter AutoHideMenuBarOption -int 3
  defaults write NSGlobalDomain _HIHideMenuBar -bool false
  defaults write NSGlobalDomain AppleMenuBarVisibleInFullscreen -bool true
  defaults write NSGlobalDomain NSRecentDocumentsLimit -int 0
  defaults write NSGlobalDomain AppleEnableMenuBarTransparency -bool true || true
  defaults write com.apple.menuextra.clock DateFormat -string 'MMM d HH:mm:ss'
  defaults write com.apple.menuextra.clock IsAnalog -bool false
  defaults write com.apple.menuextra.clock Show24Hour -bool true
  defaults write com.apple.menuextra.clock ShowSeconds -bool true
  defaults write com.apple.menuextra.clock ShowAMPM -bool false
  defaults write com.apple.menuextra.clock ShowDayOfWeek -bool false
  defaults write com.apple.menuextra.clock ShowDayOfMonth -bool true
  defaults write com.apple.menuextra.clock ShowDate -int 0
  silent killall ControlCenter || true
  silent killall SystemUIServer || true
}

linux() {
  local browser_command browser_file color color_hex
  local attempt command css_file docklike_file genmon_file genmon_pattern id plugin
  local menu_id=1 expand_id=3 actions_gap_id=5 tray_id=6
  local stats_gap_id=7 clock_id=8 clock_gap_id=9 actions_id=10
  local dock_id=11 stats_id=15
  local -a panel_plugins panel_without_stats plugin_roots=()

  panel_plugins=(
    "$menu_id" "$dock_id" "$expand_id" "$actions_id" "$actions_gap_id"
    "$stats_id" "$stats_gap_id" "$tray_id" "$clock_gap_id" "$clock_id"
  )
  for id in "${panel_plugins[@]}"; do
    [[ "$id" == "$stats_id" ]] || panel_without_stats+=("$id")
  done

  apt_install xfconf xfce4-docklike-plugin xfce4-genmon-plugin
  [[ -s /usr/local/share/icons/tux.svg ]] ||
    die 'The Tux panel icon is missing. Run the appearance phase first.'
  for command in thunar xfce4-terminal codium; do
    has "$command" || die "Top-bar launcher is missing: $command"
  done
  case "$LINUX_ARCH" in
    amd64)
      browser_command="$(command -v google-chrome || true)"
      browser_file='google-chrome.desktop'
      ;;
    arm64)
      browser_command="$(command -v brave-browser || true)"
      browser_file='brave-browser.desktop'
      ;;
  esac
  [[ -n "$browser_command" ]] || die 'The top-bar browser launcher is missing.'

  for id in 11 12 13 14; do
    rm -rf "$HOME/.config/xfce4/panel/launcher-$id"
  done
  docklike_file="$HOME/.config/xfce4/panel/docklike-$dock_id.rc"
  mkdir -p "$(dirname "$docklike_file")"
  printf '%s\n' \
    '[user]' \
    "pinned=thunar;xfce4-terminal;codium;${browser_file%.desktop};" \
    'noWindowsListIfSingle=true' >"$docklike_file"
  xfconf_set xfce4-panel "/plugins/plugin-$dock_id" string docklike

  mapfile -t plugin_roots < <(
    xfconf-query -c xfce4-panel -l |
      awk -F/ '/^\/plugins\/plugin-[0-9]+$/ { print $3 }'
  )
  for plugin in "${plugin_roots[@]}"; do
    id="${plugin#plugin-}"
    case "$id" in
      "$menu_id" | "$expand_id" | "$actions_gap_id" | "$tray_id" | \
        "$stats_gap_id" | "$clock_id" | "$clock_gap_id" | "$actions_id" | \
        "$dock_id" | "$stats_id") ;;
      *) silent xfconf-query -c xfce4-panel -p "/plugins/$plugin" -r -R || true ;;
    esac
  done

  xfconf_set xfce4-panel /panels/dark-mode bool true
  xfconf_set xfce4-panel /panels/panel-1/position string 'p=6;x=0;y=0'
  xfconf_set xfce4-panel /panels/panel-1/length uint 100
  xfconf_set xfce4-panel /panels/panel-1/position-locked bool true
  xfconf_set xfce4-panel /panels/panel-1/icon-size uint 22
  xfconf_set xfce4-panel /panels/panel-1/size uint 34
  xfconf_set xfce4-panel /panels/panel-1/background-style int 1
  xfconf_set_array xfce4-panel /panels/panel-1/background-rgba double \
    0.067 0.094 0.090 1
  xfconf_set xfce4-panel "/plugins/plugin-$menu_id" string applicationsmenu
  xfconf_set xfce4-panel "/plugins/plugin-$menu_id/show-button-title" bool false
  xfconf_set xfce4-panel "/plugins/plugin-$menu_id/button-icon" string \
    /usr/local/share/icons/tux.svg

  for id in "$expand_id" "$actions_gap_id" "$stats_gap_id" "$clock_gap_id"; do
    xfconf_set xfce4-panel "/plugins/plugin-$id" string separator
    xfconf_set xfce4-panel "/plugins/plugin-$id/style" uint 0
  done
  xfconf_set xfce4-panel "/plugins/plugin-$expand_id/expand" bool true

  xfconf_set xfce4-panel "/plugins/plugin-$tray_id" string systray
  xfconf_set xfce4-panel "/plugins/plugin-$tray_id/square-icons" bool false

  # Stop an existing Generic Monitor instance before replacing its RC file.
  # Version 4.1 writes its in-memory settings to this file during shutdown.
  xfconf_set_array xfce4-panel /panels/panel-1/plugin-ids int \
    "${panel_without_stats[@]}"
  genmon_pattern="/plugins/libgenmon[.]so $stats_id "
  silent pkill -TERM -f "$genmon_pattern" || true
  for attempt in {1..20}; do
    pgrep -f "$genmon_pattern" >/dev/null || break
    sleep 0.1
  done
  silent pkill -KILL -f "$genmon_pattern" || true
  for attempt in {1..10}; do
    pgrep -f "$genmon_pattern" >/dev/null || break
    sleep 0.1
  done
  ! pgrep -f "$genmon_pattern" >/dev/null ||
    die 'The old Generic Monitor instance did not stop.'

  sudo install -m 0755 "$INSTALLER_DIR/config/xfce/system-stats.sh" \
    /usr/local/bin/xfce-system-stats
  # Debian 13 has Generic Monitor 4.1, which reads an RC file. Version 4.2 and
  # later moved these settings to xfconf.
  genmon_file="$HOME/.config/xfce4/panel/genmon-$stats_id.rc"
  mkdir -p "$(dirname "$genmon_file")"
  printf '%s\n' \
    'Command=/usr/local/bin/xfce-system-stats' \
    'UseLabel=0' \
    'Text=' \
    'UpdatePeriod=2000' \
    'Font=Inter 8' >"$genmon_file"
  xfconf_set xfce4-panel "/plugins/plugin-$stats_id" string genmon

  xfconf_set xfce4-panel "/plugins/plugin-$clock_id" string clock
  xfconf_set xfce4-panel "/plugins/plugin-$clock_id/digital-time-font" string \
    'Inter SemiBold 10'
  xfconf_set xfce4-panel "/plugins/plugin-$clock_id/show-frame" bool false
  xfconf_set xfce4-panel "/plugins/plugin-$clock_id/tooltip-format" string '%A, %B %d, %Y'
  xfconf_set xfce4-panel "/plugins/plugin-$clock_id/mode" uint 2
  xfconf_set xfce4-panel "/plugins/plugin-$clock_id/digital-layout" uint 3
  xfconf_set xfce4-panel "/plugins/plugin-$clock_id/digital-time-format" string '%b %d  %H:%M:%S'
  xfconf_set xfce4-panel "/plugins/plugin-$clock_id/digital-date-format" string ''

  xfconf_set xfce4-panel "/plugins/plugin-$actions_id" string actions
  xfconf_set_array xfce4-panel "/plugins/plugin-$actions_id/items" string \
    +lock-screen +switch-user +separator +suspend -hibernate -hybrid-sleep \
    -separator +restart +shutdown +logout

  xfconf_set_array xfce4-panel /panels/panel-1/plugin-ids int \
    "${panel_plugins[@]}"

  color="$(machine_field "$ROOT_DIR/machine.json" color)"
  color_hex="$(machine_color_hex "$color")"
  css_file="$HOME/.config/gtk-3.0/gtk.css"
  mkdir -p "$(dirname "$css_file")"
  sed "s/@RICE_ACCENT@/$color_hex/g" \
    "$INSTALLER_DIR/config/xfce/panel.css" >"$css_file"

  [[ "$(xfconf-query -c xfce4-panel -p "/plugins/plugin-$menu_id/button-icon")" == \
    /usr/local/share/icons/tux.svg ]] || die 'The Tux application menu was not saved.'
  [[ "$(xfconf-query -c xfce4-panel -p "/plugins/plugin-$clock_id/digital-time-format")" == \
    '%b %d  %H:%M:%S' ]] || die 'The compact clock was not saved.'
  grep -Fxq 'Command=/usr/local/bin/xfce-system-stats' "$genmon_file" ||
    die 'The system stats command was not saved.'
  xfconf-query -c xfce4-panel -p "/plugins/plugin-$actions_id/items" |
    grep -Fxq '+restart' || die 'Restart is missing from the user menu.'
  silent xfce4-panel -r || true
}

configure_top_bar "$1"
