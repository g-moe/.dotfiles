#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
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

_configure() {
  safe_symlink_group 'Pi' \
    "$ROOT_DIR/.agents/AGENTS.md" "$HOME/.pi/agent/AGENTS.md"
}

mac() {
  _install
  _configure
}

linux() {
  _install
  _configure
}

install_pi "$1"
