#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_desktop_environment() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  return 0
}

linux() {
  has startxfce4 ||
    die 'Xfce is missing. Install Debian 13 with the Xfce desktop task selected.'
  [[ -x /usr/sbin/lightdm ]] ||
    die 'LightDM is missing. Install Debian 13 with the Xfce desktop task selected.'
  [[ "$(cat /etc/X11/default-display-manager 2>/dev/null || true)" == /usr/sbin/lightdm ]] ||
    die 'LightDM must be the default display manager. Reinstall Debian with the Xfce desktop task selected.'
  [[ -f /usr/share/xsessions/xfce.desktop || -f /usr/share/xsessions/xfce4.desktop ]] ||
    die 'The Xfce X11 session is missing under /usr/share/xsessions/.'
  if systemctl is-active --quiet display-manager.service; then
    systemctl is-active --quiet lightdm.service ||
      die 'Another display manager is running. Start LightDM, then run the installer again.'
  fi
  log 'Debian Xfce and LightDM are ready.'
}

configure_desktop_environment "$1"
