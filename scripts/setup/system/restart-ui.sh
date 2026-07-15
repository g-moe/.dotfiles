#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib.sh"

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
  log 'GNOME settings are live. A reboot loads the machine-name extension and the new host name.'
}

restart_user_interface "$1"
