#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_opencode() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_install() {
  # Use the same user-owned executable directory as the other coding CLIs.
  if [[ ! -x "$HOME/.local/bin/opencode" ]]; then
    mkdir -p "$HOME/.local"
    npm install --global --prefix "$HOME/.local" opencode-ai
  fi

  # An existing executable can be broken, so check every run.
  "$HOME/.local/bin/opencode" --version
}

mac() {
  _install
}

linux() {
  _install
}

install_opencode "$1"
