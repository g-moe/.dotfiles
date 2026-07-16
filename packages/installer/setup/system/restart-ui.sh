#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

restart_user_interface() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  local service
  for service in sharedfilelistd Finder Dock Spotlight ControlCenter SystemUIServer; do
    silent killall "$service" || true
  done
}

linux() {
  log 'Reboot or sign out to load the configured Xfce X11 session.'
}

restart_user_interface "$1"
