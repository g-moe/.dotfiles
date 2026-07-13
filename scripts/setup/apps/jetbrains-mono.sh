#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$APP_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

install_jetbrains_mono() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  brew_cask font-jetbrains-mono
  find "$HOME/Library/Fonts" -iname '*JetBrainsMono*' -print -quit | grep -q . ||
    die 'JetBrains Mono is missing after installation.'
}

linux() {
  apt_install fonts-jetbrains-mono
  fc-match 'JetBrains Mono' | grep -qi JetBrains ||
    die 'JetBrains Mono is missing after installation.'
}

install_jetbrains_mono "$1"
