#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

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

  defaults write com.apple.dock mineffect -string scale
  defaults write com.apple.dock minimize-to-application -bool false
  defaults write com.apple.dock launchanim -bool false
  defaults write com.apple.dock show-process-indicators -bool false
  defaults write com.apple.dock show-recents -bool false
  defaults write com.apple.dock magnification -bool true

  choice="$(choose 'Dock visibility:' 'Leave unchanged' 'Hide automatically' 'Always show')"
  case "$choice" in
    0) ;;
    1) defaults write com.apple.dock autohide -bool true ;;
    2) defaults write com.apple.dock autohide -bool false ;;
  esac

  choice="$(choose 'Dock icon size:' Small Medium Large)"
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

  choice="$(choose 'Dock position:' Bottom Left Right)"
  case "$choice" in
    0) defaults write com.apple.dock orientation -string bottom ;;
    1) defaults write com.apple.dock orientation -string left ;;
    2) defaults write com.apple.dock orientation -string right ;;
  esac

  defaults write com.apple.dock persistent-apps -array
  _mac_app '/System/Applications/Apps.app'
  _mac_app '/System/Applications/Mission Control.app'
  _mac_app '/System/Applications/iPhone Mirroring.app'
  _mac_app '/System/Applications/Passwords.app'
  _mac_app '/System/Applications/System Settings.app'
  _mac_app '/System/Applications/Utilities/Activity Monitor.app'
  _mac_app '/System/Applications/Notes.app'
  _mac_app '/Applications/Ghostty.app'
  _mac_app '/Applications/OpenCode.app'
  _mac_app '/Applications/Codex.app'
  _mac_app '/Applications/VSCodium.app'
  defaults write com.apple.dock persistent-others -array
  killall Dock
}

_require_linux_app() {
  [[ -f "/usr/share/applications/$1" ]] || die "Missing Dock application: $1"
}

linux() {
  local choice desktop_file

  gsettings set org.gnome.shell.extensions.dash-to-dock extend-height false
  gsettings set org.gnome.shell.extensions.dash-to-dock show-mounts false
  gsettings set org.gnome.shell.extensions.dash-to-dock show-trash false
  gsettings set org.gnome.shell.extensions.dash-to-dock show-show-apps-button true
  gsettings set org.gnome.shell.extensions.dash-to-dock show-running true
  gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'focus-or-previews'
  gsettings set org.gnome.shell.extensions.dash-to-dock scroll-action 'cycle-windows'

  choice="$(choose 'Dock visibility:' 'Leave unchanged' 'Hide automatically' 'Always show')"
  case "$choice" in
    0) ;;
    1)
      gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed false
      gsettings set org.gnome.shell.extensions.dash-to-dock autohide true
      gsettings set org.gnome.shell.extensions.dash-to-dock intellihide true
      ;;
    2)
      gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed true
      gsettings set org.gnome.shell.extensions.dash-to-dock autohide false
      gsettings set org.gnome.shell.extensions.dash-to-dock intellihide false
      ;;
  esac

  choice="$(choose 'Dock icon size:' Small Medium Large)"
  case "$choice" in
    0) gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 32 ;;
    1) gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 48 ;;
    2) gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 64 ;;
  esac

  choice="$(choose 'Dock position:' Bottom Left Right)"
  case "$choice" in
    0) gsettings set org.gnome.shell.extensions.dash-to-dock dock-position BOTTOM ;;
    1) gsettings set org.gnome.shell.extensions.dash-to-dock dock-position LEFT ;;
    2) gsettings set org.gnome.shell.extensions.dash-to-dock dock-position RIGHT ;;
  esac

  for desktop_file in \
    org.gnome.seahorse.Application.desktop \
    org.gnome.Settings.desktop \
    org.gnome.SystemMonitor.desktop \
    org.gnome.Notes.desktop \
    com.mitchellh.ghostty.desktop \
    ai.opencode.desktop.desktop \
    codium.desktop; do
    _require_linux_app "$desktop_file"
  done
  gsettings set org.gnome.shell favorite-apps "[
    'org.gnome.seahorse.Application.desktop',
    'org.gnome.Settings.desktop',
    'org.gnome.SystemMonitor.desktop',
    'org.gnome.Notes.desktop',
    'com.mitchellh.ghostty.desktop',
    'ai.opencode.desktop.desktop',
    'codium.desktop'
  ]"
}

configure_dock "$1"
