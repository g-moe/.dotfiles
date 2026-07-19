#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_system_monitor() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  local agent_path config_path domain service

  brew_formula mactop

  config_path="$HOME/.mactop/config.json"
  agent_path="$HOME/Library/LaunchAgents/com.dotfiles.mactop-menubar.plist"
  safe_symlink_group mactop \
    "$ROOT_DIR/mactop/config.json" "$config_path" \
    "$ROOT_DIR/mactop/com.dotfiles.mactop-menubar.plist" "$agent_path"

  if [[ ! -L "$agent_path" || "$(readlink "$agent_path")" != "$ROOT_DIR/mactop/com.dotfiles.mactop-menubar.plist" ]]; then
    log 'Skipped mactop login startup because its LaunchAgent was not linked.'
    return 0
  fi

  domain="gui/$(id -u)"
  service="$domain/com.dotfiles.mactop-menubar"
  if silent launchctl print "$service"; then
    silent launchctl bootout "$service"
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      silent launchctl print "$service" || break
      sleep 0.1
    done
  fi
  launchctl bootstrap "$domain" "$agent_path"
}

linux() {
  apt_install xfce4-taskmanager
}

install_system_monitor "$1"
