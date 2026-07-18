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

_linux_launcher() {
  local id="$1"
  local file="$2"
  local name="$3"
  local command="$4"
  local icon="$5"
  local directory="$HOME/.config/xfce4/panel/launcher-$id"

  rm -rf "$directory"
  mkdir -p "$directory"
  printf '%s\n' \
    '[Desktop Entry]' \
    'Version=1.0' \
    'Type=Application' \
    "Name=$name" \
    "Exec=$command" \
    "TryExec=${command%% *}" \
    "Icon=$icon" \
    'Terminal=false' \
    'StartupNotify=true' >"$directory/$file"
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
  local browser_command browser_file browser_icon browser_name color color_hex
  local command css_file id plugin
  local -a plugin_roots=()

  apt_install xfconf
  [[ -s /usr/local/share/icons/tux.svg ]] ||
    die 'The Tux panel icon is missing. Run the appearance phase first.'
  for command in thunar xfce4-terminal codium; do
    has "$command" || die "Top-bar launcher is missing: $command"
  done
  case "$LINUX_ARCH" in
    amd64)
      browser_command="$(command -v google-chrome || true)"
      browser_file='google-chrome.desktop'
      browser_icon='google-chrome'
      browser_name='Google Chrome'
      ;;
    arm64)
      browser_command="$(command -v brave-browser || true)"
      browser_file='brave-browser.desktop'
      browser_icon='brave-browser'
      browser_name='Brave'
      ;;
  esac
  [[ -n "$browser_command" ]] || die 'The top-bar browser launcher is missing.'

  _linux_launcher 11 thunar.desktop Files "$(command -v thunar) \"$HOME\"" org.xfce.thunar
  _linux_launcher 12 xfce4-terminal.desktop Terminal "$(command -v xfce4-terminal)" org.xfce.terminal
  _linux_launcher 13 codium.desktop VSCodium "$(command -v codium) %F" vscodium
  _linux_launcher 14 "$browser_file" "$browser_name" "$browser_command %U" "$browser_icon"

  mapfile -t plugin_roots < <(
    xfconf-query -c xfce4-panel -l |
      awk -F/ '/^\/plugins\/plugin-[0-9]+$/ { print $3 }'
  )
  for plugin in "${plugin_roots[@]}"; do
    id="${plugin#plugin-}"
    case "$id" in
      1 | 3 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14) ;;
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
    0.055 0.086 0.094 0.94
  xfconf_set_array xfce4-panel /panels/panel-1/plugin-ids int \
    1 11 12 13 14 3 10 5 6 7 8 9

  xfconf_set xfce4-panel /plugins/plugin-1 string applicationsmenu
  xfconf_set xfce4-panel /plugins/plugin-1/show-button-title bool false
  xfconf_set xfce4-panel /plugins/plugin-1/button-icon string \
    /usr/local/share/icons/tux.svg

  for id in 3 5 7 9; do
    xfconf_set xfce4-panel "/plugins/plugin-$id" string separator
    xfconf_set xfce4-panel "/plugins/plugin-$id/style" uint 0
  done
  xfconf_set xfce4-panel /plugins/plugin-3/expand bool true

  xfconf_set xfce4-panel /plugins/plugin-6 string systray
  xfconf_set xfce4-panel /plugins/plugin-6/square-icons bool false

  xfconf_set xfce4-panel /plugins/plugin-8 string clock
  xfconf_set xfce4-panel /plugins/plugin-8/digital-time-font string \
    'JetBrains Mono SemiBold 10'
  xfconf_set xfce4-panel /plugins/plugin-8/show-frame bool false
  xfconf_set xfce4-panel /plugins/plugin-8/tooltip-format string '%A, %B %d, %Y'
  xfconf_set xfce4-panel /plugins/plugin-8/mode uint 2
  xfconf_set xfce4-panel /plugins/plugin-8/digital-layout uint 3
  xfconf_set xfce4-panel /plugins/plugin-8/digital-time-format string '%b %d  %H:%M'
  xfconf_set xfce4-panel /plugins/plugin-8/digital-date-format string ''

  xfconf_set xfce4-panel /plugins/plugin-10 string actions
  xfconf_set_array xfce4-panel /plugins/plugin-10/items string \
    +lock-screen +switch-user +separator +suspend -hibernate -hybrid-sleep \
    -separator +restart +shutdown +logout

  for id in 11 12 13 14; do
    xfconf_set xfce4-panel "/plugins/plugin-$id" string launcher
  done
  xfconf_set_array xfce4-panel /plugins/plugin-11/items string thunar.desktop
  xfconf_set_array xfce4-panel /plugins/plugin-12/items string xfce4-terminal.desktop
  xfconf_set_array xfce4-panel /plugins/plugin-13/items string codium.desktop
  xfconf_set_array xfce4-panel /plugins/plugin-14/items string "$browser_file"

  color="$(machine_field "$ROOT_DIR/machine.json" color)"
  color_hex="$(machine_color_hex "$color")"
  css_file="$HOME/.config/gtk-3.0/gtk.css"
  mkdir -p "$(dirname "$css_file")"
  sed "s/@RICE_ACCENT@/$color_hex/g" \
    "$INSTALLER_DIR/config/xfce/panel.css" >"$css_file"

  [[ "$(xfconf-query -c xfce4-panel -p /plugins/plugin-1/button-icon)" == \
    /usr/local/share/icons/tux.svg ]] || die 'The Tux application menu was not saved.'
  [[ "$(xfconf-query -c xfce4-panel -p /plugins/plugin-8/digital-time-format)" == \
    '%b %d  %H:%M' ]] || die 'The compact clock was not saved.'
  xfconf-query -c xfce4-panel -p /plugins/plugin-10/items |
    grep -Fxq '+restart' || die 'Restart is missing from the user menu.'
  silent xfce4-panel -r || true
}

configure_top_bar "$1"
