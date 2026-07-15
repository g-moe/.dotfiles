#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$APP_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib.sh"

install_tailscale() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  local choice

  choice="$(ask_select 'Install Tailscale as:' Skip 'Command-line service' 'Menu bar app')"
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
  local choice ID='' VERSION_CODENAME=''

  choice="$(ask_select 'Install Tailscale?' Skip 'System service')"
  [[ "$choice" == 1 ]] || return 0
  # shellcheck disable=SC1091
  . /etc/os-release
  install_apt_key \
    "https://pkgs.tailscale.com/stable/ubuntu/${VERSION_CODENAME}.noarmor.gpg" \
    /usr/share/keyrings/tailscale-archive-keyring.gpg
  install_root_file /etc/apt/sources.list.d/tailscale.list "$(curl -fsSL \
    "https://pkgs.tailscale.com/stable/ubuntu/${VERSION_CODENAME}.tailscale-keyring.list")"
  sudo apt-get update
  apt_install tailscale
  sudo systemctl enable --now tailscaled.service
}

install_tailscale "$1"
