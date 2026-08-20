#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_pi() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_install() {
  [[ -x "$HOME/.local/bin/pi" ]] && return 0
  mkdir -p "$HOME/.local"
  npm install -g --ignore-scripts --min-release-age=0 --prefix "$HOME/.local" \
    @earendil-works/pi-coding-agent
}

mac() {
  _install
}

linux() {
  _install
}

install_pi "$1"
