#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$APP_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

install_voice_dictation() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  brew_cask voiceink
}

linux() {
  local package

  [[ "$(dpkg --print-architecture)" == amd64 ]] ||
    die 'OpenWhispr does not publish a Linux ARM package.'
  package="$(download_github_asset OpenWhispr/openwhispr \
    'OpenWhispr-.*-linux-amd64\.deb$' .deb)"
  apt_install "$package"
  rm -f "$package"
  has open-whispr || die 'OpenWhispr did not become available.'
}

install_voice_dictation "$1"
