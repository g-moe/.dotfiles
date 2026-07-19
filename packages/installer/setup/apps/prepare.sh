#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

prepare_apps() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  install_homebrew
  brew update
  brew_formula jq
}

linux() {
  sudo apt-get update
  apt_install build-essential ca-certificates curl file git gpg jq procps
}

prepare_apps "$1"
