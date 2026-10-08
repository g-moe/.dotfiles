#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_cursor_cli() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_install() {
  # Use the vendor installer only when the stable executable is missing.
  # It supplies both agent and cursor-agent under ~/.local/bin.
  if [[ ! -x "$HOME/.local/bin/cursor-agent" ]]; then
    curl -fsSL https://cursor.com/install | bash
  fi

  # Check the installed CLI on first and repeat runs without starting login.
  "$HOME/.local/bin/cursor-agent" --version
}

mac() {
  _install
}

linux() {
  _install
}

install_cursor_cli "$1"
