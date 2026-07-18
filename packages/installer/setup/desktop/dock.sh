#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_dock() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_mac_app() {
  local path="$1"
  local entry

  [[ -d "$path" ]] || die "Missing Dock application: $path"
  entry="<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>${path}</string><key>_CFURLStringType</key><integer>0</integer></dict></dict><key>tile-type</key><string>file-tile</string></dict>"
  defaults write com.apple.dock persistent-apps -array-add "$entry"
}

mac() {
  local choice

  choice="$(ask_choice 'Dock setup:' 'Leave unchanged' 'Hide automatically' 'Always show')"
  [[ "$choice" != 0 ]] || return 0

  defaults write com.apple.dock mineffect -string scale
  defaults write com.apple.dock minimize-to-application -bool false
  defaults write com.apple.dock launchanim -bool false
  defaults write com.apple.dock show-process-indicators -bool false
  defaults write com.apple.dock show-recents -bool false
  defaults write com.apple.dock magnification -bool true

  case "$choice" in
    1) defaults write com.apple.dock autohide -bool true ;;
    2) defaults write com.apple.dock autohide -bool false ;;
  esac

  choice="$(ask_choice 'Dock icon size:' Small Medium Large)"
  case "$choice" in
    0)
      defaults write com.apple.dock tilesize -int 32
      defaults write com.apple.dock largesize -int 64
      ;;
    1)
      defaults write com.apple.dock tilesize -int 48
      defaults write com.apple.dock largesize -int 96
      ;;
    2)
      defaults write com.apple.dock tilesize -int 64
      defaults write com.apple.dock largesize -int 128
      ;;
  esac

  choice="$(ask_choice 'Dock position:' Bottom Left Right)"
  case "$choice" in
    0) defaults write com.apple.dock orientation -string bottom ;;
    1) defaults write com.apple.dock orientation -string left ;;
    2) defaults write com.apple.dock orientation -string right ;;
  esac

  defaults write com.apple.dock persistent-apps -array
  _mac_app '/System/Library/CoreServices/Finder.app'
  _mac_app '/System/Applications/Apps.app'
  _mac_app '/System/Applications/Mission Control.app'
  _mac_app '/System/Applications/System Settings.app'
  _mac_app '/Applications/Ghostty.app'
  _mac_app '/Applications/VSCodium.app'
  _mac_app '/Applications/Google Chrome.app'
  defaults write com.apple.dock persistent-others -array
  killall Dock
}

linux() {
  local id
  local -a kept_panels=() panel_ids=() panel_plugins=()

  mapfile -t panel_ids < <(
    xfconf-query -c xfce4-panel -p /panels | awk '/^[0-9]+$/ { print }'
  )
  for id in "${panel_ids[@]}"; do
    if [[ "$id" == 2 ]]; then
      mapfile -t panel_plugins < <(
        xfconf-query -c xfce4-panel -p /panels/panel-2/plugin-ids |
          awk '/^[0-9]+$/ { print }'
      )
    else
      kept_panels+=("$id")
    fi
  done

  if [[ " ${panel_ids[*]} " == *' 2 '* ]]; then
    ((${#kept_panels[@]})) || die 'Removing the lower panel would remove every Xfce panel.'
    xfconf_set_array xfce4-panel /panels int "${kept_panels[@]}"
    silent xfconf-query -c xfce4-panel -p /panels/panel-2 -r -R || true
    for id in "${panel_plugins[@]}"; do
      silent xfconf-query -c xfce4-panel -p "/plugins/plugin-$id" -r -R || true
    done
  fi
}

configure_dock "$1"
