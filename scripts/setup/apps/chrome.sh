#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$APP_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

install_chrome() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  brew_cask google-chrome
  [[ -d '/Applications/Google Chrome.app' ]] || die 'Google Chrome is missing after installation.'
}

linux() {
  [[ "$(dpkg --print-architecture)" == amd64 ]] ||
    die 'Google does not publish Chrome for Linux ARM.'
  install_apt_key \
    https://dl.google.com/linux/linux_signing_key.pub \
    /usr/share/keyrings/google-chrome.gpg \
    dearmor
  install_root_file /etc/apt/sources.list.d/google-chrome.sources "$(cat <<'EOF'
Types: deb
URIs: https://dl.google.com/linux/chrome/deb/
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/google-chrome.gpg
EOF
)"
  sudo apt-get update
  apt_install google-chrome-stable
  has google-chrome || die 'Google Chrome is missing after installation.'
}

install_chrome "$1"
