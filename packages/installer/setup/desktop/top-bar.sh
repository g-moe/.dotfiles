#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
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
  local id plugin_type
  local panel_property='/panels/panel-1/plugin-ids'
  local -a panel_ids=() kept_ids=() removed_ids=() set_args=()

  if silent xfconf-query -c xfce4-panel -p /plugins/plugin-1/show-button-title; then
    xfconf-query -c xfce4-panel -p /plugins/plugin-1/show-button-title -s false
  else
    xfconf-query -c xfce4-panel -p /plugins/plugin-1/show-button-title \
      -n -t bool -s false
  fi
  if silent xfconf-query -c xfce4-panel -p /plugins/plugin-1/button-icon; then
    xfconf-query -c xfce4-panel -p /plugins/plugin-1/button-icon -s start-here-symbolic
  else
    xfconf-query -c xfce4-panel -p /plugins/plugin-1/button-icon \
      -n -t string -s start-here-symbolic
  fi

  mapfile -t panel_ids < <(
    xfconf-query -c xfce4-panel -p "$panel_property" |
      awk '/^[0-9]+$/ { print }'
  )

  for id in "${panel_ids[@]}"; do
    plugin_type="$(
      xfconf-query -c xfce4-panel -p "/plugins/plugin-$id" 2>/dev/null || true
    )"
    case "$plugin_type" in
      pager | tasklist) removed_ids+=("$id") ;;
      *) kept_ids+=("$id") ;;
    esac
  done

  ((${#removed_ids[@]})) || return 0
  ((${#kept_ids[@]})) || die 'Removing the window list would empty the top panel.'

  set_args=(-a)
  for id in "${kept_ids[@]}"; do
    set_args+=(-t int -s "$id")
  done
  xfconf-query -c xfce4-panel -p "$panel_property" "${set_args[@]}"

  for id in "${removed_ids[@]}"; do
    xfconf-query -c xfce4-panel -p "/plugins/plugin-$id" -r -R
  done

  if xfconf-query -c xfce4-panel -lv |
    awk '$2 == "pager" || $2 == "tasklist" { found=1 } END { exit !found }'; then
    die 'The window or workspace list is still present in the Xfce top panel.'
  fi
}

configure_top_bar "$1"
