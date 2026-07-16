#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_display_server() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  return 0
}

# Force the GDM login path onto Xorg. Wayland breaks classic shared-desktop VNC.
linux_gdm_conf() {
  local candidate
  for candidate in /etc/gdm3/custom.conf /etc/gdm/custom.conf; do
    [[ -f "$candidate" ]] || continue
    printf '%s\n' "$candidate"
    return 0
  done
  return 1
}

linux() {
  local conf
  conf="$(linux_gdm_conf)" || die 'GDM custom.conf not found; cannot force X11.'

  if grep -qE '^[[:space:]]*#?WaylandEnable=' "$conf"; then
    sudo sed -i -E 's/^[[:space:]]*#?WaylandEnable=.*/WaylandEnable=false/' "$conf"
  elif grep -qE '^[[:space:]]*\[daemon\]' "$conf"; then
    sudo sed -i -E '/^[[:space:]]*\[daemon\]/a WaylandEnable=false' "$conf"
  else
    printf '\n[daemon]\nWaylandEnable=false\n' | silent sudo tee -a "$conf"
  fi

  grep -qE '^WaylandEnable=false$' "$conf" ||
    die "Failed to force X11 in $conf."
  log 'Display server set to X11 (Xorg). Re-login or reboot to apply.'
}

configure_display_server "$1"
