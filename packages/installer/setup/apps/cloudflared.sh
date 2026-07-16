#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_cloudflared() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  brew_formula cloudflared
}

linux() {
  install_apt_key \
    https://pkg.cloudflare.com/cloudflare-main.gpg \
    /usr/share/keyrings/cloudflare-main.gpg
  install_root_file /etc/apt/sources.list.d/cloudflared.sources "$(cat <<'EOF'
Types: deb
URIs: https://pkg.cloudflare.com/cloudflared
Suites: any
Components: main
Signed-By: /usr/share/keyrings/cloudflare-main.gpg
EOF
)"
  sudo apt-get update
  apt_install cloudflared
}

install_cloudflared "$1"
