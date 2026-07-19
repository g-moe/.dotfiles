#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_cloudflare() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

install_wrangler() {
  activate_repo_node "$ROOT_DIR" || die 'Node.js is not available.'
  npm install --global wrangler@latest
}

mac() {
  brew_formula cloudflared
  install_wrangler
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
  install_wrangler
}

install_cloudflare "$1"
