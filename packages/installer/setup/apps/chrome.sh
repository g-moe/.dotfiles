#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

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
  case "$LINUX_ARCH" in
    amd64) install_google_chrome ;;
    arm64) install_brave ;;
    *) die "No Chrome-family browser is configured for $LINUX_ARCH" ;;
  esac
}

install_google_chrome() {
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

install_brave() {
  install_apt_key \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
    /usr/share/keyrings/brave-browser-archive-keyring.gpg
  install_root_file /etc/apt/sources.list.d/brave-browser.sources "$(cat <<'EOF'
Types: deb
URIs: https://brave-browser-apt-release.s3.brave.com
Suites: stable
Components: main
Architectures: arm64
Signed-By: /usr/share/keyrings/brave-browser-archive-keyring.gpg
EOF
)"
  sudo apt-get update
  apt_install brave-browser
  has brave-browser || die 'Brave is missing after installation.'
}

install_chrome "$1"
