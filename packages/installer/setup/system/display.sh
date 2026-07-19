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

# LightDM + Xfce X11 only. The Debian installer supplies all desktop packages.
linux() {
  [[ -x /usr/sbin/lightdm ]] || die 'LightDM is required; install Debian with the Xfce desktop task selected.'
  [[ "$(cat /etc/X11/default-display-manager 2>/dev/null || true)" == /usr/sbin/lightdm ]] ||
    die 'LightDM must be the default display manager.'

  install_root_file /etc/lightdm/lightdm.conf.d/50-machine-x11.conf \
    '[Seat:*]
user-session=xfce
greeter-session=lightdm-gtk-greeter'

  # Only session choices are removed; Xfce's X11 session stays installed.
  if [[ -d /usr/share/wayland-sessions ]]; then
    sudo find /usr/share/wayland-sessions -type f -name '*.desktop' -delete
  fi

  [[ -f /usr/share/xsessions/xfce.desktop || -f /usr/share/xsessions/xfce4.desktop ]] ||
    die 'The Xfce X11 session is missing under /usr/share/xsessions/.'
  log 'LightDM will start the Xfce X11 session. Reboot or sign out to apply it.'
}

configure_display_server "$1"
