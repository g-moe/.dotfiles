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

# Noninteractive: LightDM becomes the only display manager.
linux_select_lightdm() {
  sudo debconf-set-selections <<'EOF'
lightdm shared/default-x-display-manager select lightdm
gdm3 shared/default-x-display-manager select lightdm
EOF
  printf '%s\n' /usr/sbin/lightdm | silent sudo tee /etc/X11/default-display-manager
  sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure lightdm
}

# Hard cut: drop the Ubuntu GNOME session stack so XFCE is the desktop.
linux_purge_gnome_desktop() {
  apt_purge gdm3 ubuntu-session ubuntu-desktop ubuntu-desktop-minimal
  sudo apt-get autoremove --purge -y
}

linux() {
  # Seed debconf before install so apt never prompts for the display manager.
  sudo debconf-set-selections <<'EOF'
lightdm shared/default-x-display-manager select lightdm
gdm3 shared/default-x-display-manager select lightdm
EOF
  printf '%s\n' /usr/sbin/lightdm | silent sudo tee /etc/X11/default-display-manager

  apt_install xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
  linux_select_lightdm
  linux_purge_gnome_desktop

  [[ "$(cat /etc/X11/default-display-manager 2>/dev/null || true)" == /usr/sbin/lightdm ]] ||
    die 'LightDM is not the default display manager.'
  has startxfce4 || die 'XFCE did not install (startxfce4 missing).'
  log 'Desktop environment is XFCE + LightDM (GNOME session stack purged). Reboot.'
}

configure_desktop_environment "$1"
