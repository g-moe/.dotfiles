#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
. "$SCRIPTS_DIR/lib/lib.sh"

configure_remapping() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  safe_symlink \
    "$ROOT_DIR/karabiner/karabiner.json" \
    "$HOME/.config/karabiner/karabiner.json"
}

linux() {
  sudo systemctl enable --now input-remapper-daemon.service
  log 'Input Remapper is ready. Its presets stay device-specific because Linux names each physical keyboard differently.'
}

configure_remapping "$1"
