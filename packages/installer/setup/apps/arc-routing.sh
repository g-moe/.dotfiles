#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_arc_routing() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  safe_symlink \
    "$ROOT_DIR/arc/StorableLinkRouting.json" \
    "$HOME/Library/Application Support/Arc/StorableLinkRouting.json"
}

linux() {
  return 0
}

configure_arc_routing "$1"
