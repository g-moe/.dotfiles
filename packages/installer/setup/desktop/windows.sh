#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

HAMMERSPOON_CONFIG_DIR="$HOME/.hammerspoon"
HAMMERSPOON_INIT="$HAMMERSPOON_CONFIG_DIR/init.lua"
HAMMERSPOON_STATE="$HAMMERSPOON_CONFIG_DIR/.dotfiles-window-configuration"
HAMMERSPOON_INIT_OWNER="$HAMMERSPOON_CONFIG_DIR/.dotfiles-created-init"
HAMMERSPOON_STARTUP="$HOME/Library/LaunchAgents/com.dotfiles.window-management.hammerspoon.plist"
LOADER_BEGIN='-- BEGIN dotfiles installer: window management'
LOADER_END='-- END dotfiles installer: window management'

configure_windows() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  local choice

  choice="$(ask_choice 'Window management' Skip Disable Enable)"
  case "$choice" in
    0) return 0 ;;
    1) mac_disable_window_management ;;
    2) mac_choose_window_configuration ;;
  esac
}

mac_choose_window_configuration() {
  local choice configuration

  choice="$(ask_choice 'Window configuration' 'Center + Fill')"
  case "$choice" in
    0) configuration='center-fill' ;;
  esac

  mac_enable_window_configuration "$configuration"
}

mac_enable_window_configuration() {
  local configuration="$1"

  case "$configuration" in
    center-fill) mac_enable_center_fill ;;
    *) die "Unknown window configuration: $configuration" ;;
  esac
}

mac_enable_center_fill() {
  mac_install_hammerspoon
  mac_write_hammerspoon_loader 'center-fill'
  mac_write_hammerspoon_startup

  defaults write NSGlobalDomain AppleActionOnDoubleClick -string Fill
  defaults write NSGlobalDomain AppleMiniaturizeOnDoubleClick -bool false
  defaults write com.apple.WindowManager EnableTilingByEdgeDrag -bool false
  defaults write com.apple.WindowManager EnableTopTilingByEdgeDrag -bool false
  defaults write com.apple.WindowManager EnableTilingOptionAccelerator -bool false
  defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false

  mac_restart_hammerspoon
  log 'Hammerspoon needs macOS Accessibility permission to manage windows.'
  log 'Grant it in Privacy & Security > Accessibility; the installer cannot grant it for you.'
  open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility' || true
}

mac_install_hammerspoon() {
  if [[ -d /Applications/Hammerspoon.app || -d "$HOME/Applications/Hammerspoon.app" ]]; then
    return 0
  fi

  install_homebrew
  brew_cask hammerspoon
}

mac_remove_hammerspoon_loader() {
  local begin_count end_count temporary_file

  [[ -f "$HAMMERSPOON_INIT" ]] || return 0
  begin_count="$(grep -cFx -- "$LOADER_BEGIN" "$HAMMERSPOON_INIT" || true)"
  end_count="$(grep -cFx -- "$LOADER_END" "$HAMMERSPOON_INIT" || true)"
  [[ "$begin_count" == "$end_count" ]] ||
    die "The managed Hammerspoon lines in $HAMMERSPOON_INIT are incomplete."
  [[ "$begin_count" != 0 ]] || return 0

  temporary_file="$(mktemp)"
  awk -v begin="$LOADER_BEGIN" -v end="$LOADER_END" '
    $0 == begin { managed = 1; next }
    $0 == end { managed = 0; next }
    !managed { print }
  ' "$HAMMERSPOON_INIT" >"$temporary_file"
  # Write through an existing symlink instead of replacing the user's link.
  cp "$temporary_file" "$HAMMERSPOON_INIT"
  rm -f "$temporary_file"
}

mac_write_hammerspoon_loader() {
  local configuration="$1"
  local source_file="$HOME/.dotfiles/packages/installer/config/window-management/$configuration.lua"

  [[ -f "$source_file" ]] || die "Missing window configuration: $source_file"
  mkdir -p "$HAMMERSPOON_CONFIG_DIR"
  if [[ -L "$HAMMERSPOON_INIT" && ! -e "$HAMMERSPOON_INIT" ]]; then
    die "Hammerspoon init link has no target: $HAMMERSPOON_INIT"
  fi
  if [[ ! -e "$HAMMERSPOON_INIT" ]]; then
    : >"$HAMMERSPOON_INIT"
    : >"$HAMMERSPOON_INIT_OWNER"
  fi

  mac_remove_hammerspoon_loader
  if [[ -s "$HAMMERSPOON_INIT" ]]; then
    printf '\n' >>"$HAMMERSPOON_INIT"
  fi
  printf '%s\n' \
    "$LOADER_BEGIN" \
    "dofile(os.getenv(\"HOME\") .. \"/.dotfiles/packages/installer/config/window-management/$configuration.lua\")" \
    "$LOADER_END" >>"$HAMMERSPOON_INIT"
  printf '%s\n' "$configuration" >"$HAMMERSPOON_STATE"
}

mac_write_hammerspoon_startup() {
  mkdir -p "$(dirname "$HAMMERSPOON_STARTUP")"
  cat >"$HAMMERSPOON_STARTUP" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.dotfiles.window-management.hammerspoon</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>-g</string>
    <string>-a</string>
    <string>Hammerspoon</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
PLIST
  plutil -lint "$HAMMERSPOON_STARTUP" >/dev/null
}

mac_hammerspoon_has_other_configuration() {
  [[ -f "$HAMMERSPOON_INIT" ]] || return 1
  grep -q '[^[:space:]]' "$HAMMERSPOON_INIT"
}

mac_restart_hammerspoon() {
  local was_running=false

  if pgrep -x Hammerspoon >/dev/null; then
    was_running=true
    osascript -e 'tell application "Hammerspoon" to quit' || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      pgrep -x Hammerspoon >/dev/null || break
      sleep 0.1
    done
    silent pkill -x Hammerspoon || true
  fi

  open -g -a Hammerspoon
  if [[ "$was_running" == true ]]; then
    log 'Reloaded Hammerspoon.'
  else
    log 'Started Hammerspoon.'
  fi
}

mac_disable_window_management() {
  local loader_was_managed=false was_running=false

  if pgrep -x Hammerspoon >/dev/null; then
    was_running=true
  fi
  if [[ -f "$HAMMERSPOON_INIT" ]] && grep -qFx -- "$LOADER_BEGIN" "$HAMMERSPOON_INIT"; then
    loader_was_managed=true
  fi

  mac_remove_hammerspoon_loader
  rm -f "$HAMMERSPOON_STATE"

  if [[ -f "$HAMMERSPOON_INIT_OWNER" ]]; then
    if [[ -f "$HAMMERSPOON_INIT" ]] && ! grep -q '[^[:space:]]' "$HAMMERSPOON_INIT"; then
      rm -f "$HAMMERSPOON_INIT"
    fi
    rm -f "$HAMMERSPOON_INIT_OWNER"
  fi

  if [[ -f "$HAMMERSPOON_STARTUP" ]]; then
    if mac_hammerspoon_has_other_configuration; then
      log 'Kept Hammerspoon at login because another Hammerspoon configuration remains.'
    else
      silent launchctl bootout "gui/$(id -u)" "$HAMMERSPOON_STARTUP" || true
      rm -f "$HAMMERSPOON_STARTUP"
    fi
  fi

  if [[ "$loader_was_managed" == true && "$was_running" == true ]]; then
    mac_restart_hammerspoon
  fi
}

linux() {
  local layout='CHM|'

  xfconf-query -c xfwm4 -p /general/button_layout -s "$layout"
  [[ "$(xfconf-query -c xfwm4 -p /general/button_layout)" == "$layout" ]] ||
    die 'The Mac-style window-button order was not saved.'
}

configure_windows "$1"
