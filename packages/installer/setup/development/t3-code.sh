#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_t3_code() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_install() {
  [[ -x "$HOME/.local/bin/t3" ]] && return 0
  ask_binary 'Install the T3 Code CLI?' || return 0
  curl -fsSL https://t3.codes/install.sh | sh
}

mac() {
  _install
}

linux() {
  _install
}

install_t3_code "$1"
