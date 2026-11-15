#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

WAVE_REPOSITORY='https://github.com/g-moe/wave.git'
WAVE_SOURCE_DIR="$HOME/code/dev/wave"

install_wave() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  [[ -d "$WAVE_SOURCE_DIR/.git" ]] && return 0
  [[ ! -e "$WAVE_SOURCE_DIR" ]] || die "Refusing to replace $WAVE_SOURCE_DIR"
  mkdir -p "$(dirname "$WAVE_SOURCE_DIR")"
  git clone "$WAVE_REPOSITORY" "$WAVE_SOURCE_DIR"
}

linux() {
  :
}

install_wave "$1"
