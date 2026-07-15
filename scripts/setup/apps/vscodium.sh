#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$APP_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib.sh"

install_vscodium() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  brew_cask vscodium
  [[ -d /Applications/VSCodium.app ]] || die 'VSCodium is missing after installation.'
}

linux() {
  install_apt_key \
    https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
    /usr/share/keyrings/vscodium-archive-keyring.gpg \
    dearmor
  install_root_file /etc/apt/sources.list.d/vscodium.sources "$(cat <<'EOF'
Types: deb
URIs: https://download.vscodium.com/debs
Suites: vscodium
Components: main
Architectures: amd64 arm64
Signed-By: /usr/share/keyrings/vscodium-archive-keyring.gpg
EOF
)"
  sudo apt-get update
  apt_install codium
  has codium || die 'VSCodium is missing after installation.'
}

install_vscodium "$1"
