#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

configure_handoff() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  defaults -currentHost write com.apple.coreservices.useractivityd ActivityAdvertisingAllowed -bool false
  defaults -currentHost write com.apple.coreservices.useractivityd ActivityReceivingAllowed -bool false
  killall useractivityd >/dev/null 2>&1 || true
}

linux() {
  log 'GNOME has no built-in Handoff service to disable.'
}

configure_handoff "$1"
