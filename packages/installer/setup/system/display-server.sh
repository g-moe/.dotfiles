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

# LightDM + XFCE X11 only. Wayland session entries are removed so login cannot
# pick GNOME/XFCE Wayland. Desktop packages are system/desktop-environment.sh.
linux() {
  [[ -x /usr/sbin/lightdm ]] || die 'LightDM is required; run the desktop-environment strategy first.'
  [[ "$(cat /etc/X11/default-display-manager 2>/dev/null || true)" == /usr/sbin/lightdm ]] ||
    die 'LightDM must be the default display manager before forcing X11.'

  install_root_file /etc/lightdm/lightdm.conf.d/50-machine-x11.conf \
    '[Seat:*]
user-session=xfce
greeter-session=lightdm-gtk-greeter'

  # Session .desktop files only — do not purge xfce4-session (still needed for X11).
  if [[ -d /usr/share/wayland-sessions ]]; then
    sudo find /usr/share/wayland-sessions -type f -name '*.desktop' -delete
  fi

  [[ -f /usr/share/xsessions/xfce.desktop || -f /usr/share/xsessions/xfce4.desktop ]] ||
    die 'XFCE X11 session is missing under /usr/share/xsessions/.'
  log 'Display server locked to X11 (LightDM → XFCE). Reboot to apply.'
}

configure_display_server "$1"
