#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_temperature_monitor() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  # mactop remains the sensor monitor; Macs Fan Control provides better fan controls.
  brew_cask macs-fan-control
}

linux() {
  apt_install psensor lm-sensors
}

install_temperature_monitor "$1"
