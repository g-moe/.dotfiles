#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$APP_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

install_docker() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  brew_cask docker-desktop
}

linux() {
  local ID='' VERSION_CODENAME=''

  # shellcheck disable=SC1091
  . /etc/os-release
  install_apt_key \
    https://download.docker.com/linux/ubuntu/gpg \
    /etc/apt/keyrings/docker.asc
  install_root_file /etc/apt/sources.list.d/docker.sources "$(cat <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $VERSION_CODENAME
Components: stable
Architectures: $LINUX_ARCH
Signed-By: /etc/apt/keyrings/docker.asc
EOF
)"
  sudo apt-get update
  apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker "${USER:-$(id -un)}"
  sudo systemctl enable --now docker
}

install_docker "$1"
