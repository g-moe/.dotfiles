#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_tailscale() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  local choice

  choice="$(ask_choice 'Install Tailscale as:' Skip 'Command-line service' 'Menu bar app')"
  case "$choice" in
    0) ;;
    1)
      brew_formula tailscale
      sudo "$(command -v brew)" services start tailscale
      ;;
    2) brew_cask tailscale-app ;;
  esac
}

linux() {
  ask_binary 'Install Tailscale?' || return 0
  install_apt_key \
    "https://pkgs.tailscale.com/stable/debian/${LINUX_CODENAME}.noarmor.gpg" \
    /usr/share/keyrings/tailscale-archive-keyring.gpg
  install_root_file /etc/apt/sources.list.d/tailscale.list "$(curl -fsSL \
    "https://pkgs.tailscale.com/stable/debian/${LINUX_CODENAME}.tailscale-keyring.list")"
  sudo apt-get update
  apt_install tailscale
  sudo systemctl enable --now tailscaled.service
}

install_tailscale "$1"
