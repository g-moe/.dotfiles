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
  _mac_app '/System/Applications/Mission Control.app'
  _mac_app '/System/Applications/System Settings.app'
  _mac_app '/Applications/Ghostty.app'
  _mac_app '/Applications/VSCodium.app'
  _mac_app '/Applications/Google Chrome.app'
  defaults write com.apple.dock persistent-others -array
  killall Dock
}

linux() {
  local id temporary_dir
  local dock_path='/net/launchpad/plank/docks/dock1/'
  local theme_dir="$HOME/.local/share/plank/themes/WhiteSur"
  local launchers_dir="$HOME/.config/plank/dock1/launchers"
  local autostart_file="$HOME/.config/autostart/plank.desktop"
  local -a panel_ids=() panel_plugins=() kept_panels=() set_args=()

  apt_install dconf-cli plank
  temporary_dir="$(mktemp -d)"

  cat >"$temporary_dir/dock.theme" <<'THEME'
# WhiteSur Plank theme by Vince Liuice.
[PlankTheme]
TopRoundness=23
BottomRoundness=23
LineWidth=0
OuterStrokeColor=0;;0;;0;;0
FillStartColor=209;;209;;209;;150
FillEndColor=209;;209;;209;;150
InnerStrokeColor=210;;210;;210;;50

[PlankDockTheme]
HorizPadding=1
TopPadding=2
BottomPadding=2
ItemPadding=3
IndicatorSize=5
IconShadowSize=0
UrgentBounceHeight=2
LaunchBounceHeight=0.7
FadeOpacity=1
ClickTime=300
UrgentBounceTime=0
LaunchBounceTime=600
ActiveTime=300
SlideTime=100
FadeTime=250
HideTime=200
GlowSize=0
GlowTime=0
GlowPulseTime=0
UrgentHueShift=150
ItemMoveTime=200
CascadeHide=true
BadgeColor=0;;0;;0;;0
THEME

  cat >"$temporary_dir/plank.desktop" <<'AUTOSTART'
[Desktop Entry]
Type=Application
Name=Plank
Comment=Mac-style application dock
Exec=plank
OnlyShowIn=XFCE;
Terminal=false
Hidden=false
AUTOSTART

  mkdir -p "$theme_dir" "$launchers_dir" "$(dirname "$autostart_file")"
  install -m 0644 "$temporary_dir/dock.theme" "$theme_dir/dock.theme"
  install -m 0644 "$temporary_dir/plank.desktop" "$autostart_file"

  printf '%s\n' '[PlankDockItemPreferences]' \
    'Launcher=file:///usr/share/applications/thunar.desktop' \
    >"$launchers_dir/01-thunar.dockitem"
  printf '%s\n' '[PlankDockItemPreferences]' \
    'Launcher=file:///usr/share/applications/xfce4-terminal.desktop' \
    >"$launchers_dir/02-terminal.dockitem"
  printf '%s\n' '[PlankDockItemPreferences]' \
    'Launcher=file:///usr/share/applications/codium.desktop' \
    >"$launchers_dir/03-codium.dockitem"
  printf '%s\n' '[PlankDockItemPreferences]' \
    'Launcher=file:///usr/share/applications/brave-browser.desktop' \
    >"$launchers_dir/04-browser.dockitem"

  silent dbus-run-session -- dconf write /net/launchpad/plank/enabled-docks "['dock1']"
  silent dbus-run-session -- dconf write "${dock_path}theme" "'WhiteSur'"
  silent dbus-run-session -- dconf write "${dock_path}icon-size" 48
  silent dbus-run-session -- dconf write "${dock_path}zoom-enabled" true
  silent dbus-run-session -- dconf write "${dock_path}zoom-percent" 135
  silent dbus-run-session -- dconf write "${dock_path}show-dock-item" false
  silent dbus-run-session -- dconf write "${dock_path}lock-items" true
  silent dbus-run-session -- dconf write "${dock_path}dock-items" \
    "['01-thunar.dockitem', '02-terminal.dockitem', '03-codium.dockitem', '04-browser.dockitem']"

  [[ "$(dbus-run-session -- dconf read "${dock_path}theme")" == "'WhiteSur'" ]] ||
    die 'The WhiteSur Plank theme was not saved.'
  [[ -f "$theme_dir/dock.theme" && -f "$autostart_file" ]] ||
    die 'The Plank theme or startup entry is missing.'

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

  if ((${#panel_plugins[@]})); then
    set_args=(-a)
    for id in "${kept_panels[@]}"; do
      set_args+=(-t int -s "$id")
    done
    xfconf-query -c xfce4-panel -p /panels "${set_args[@]}"
    xfconf-query -c xfce4-panel -p /panels/panel-2 -r -R
    for id in "${panel_plugins[@]}"; do
      xfconf-query -c xfce4-panel -p "/plugins/plugin-$id" -r -R
    done
  fi

  rm -rf "$temporary_dir"
}

configure_dock "$1"
