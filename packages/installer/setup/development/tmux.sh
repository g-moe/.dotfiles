#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_tmux() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_configure() {
  local tpm_source="$1"

  safe_symlink_group tmux \
    "$ROOT_DIR/tmux/tmux.conf" "$HOME/.tmux.conf" \
    "$tpm_source" "$HOME/.tmux/plugins/tpm"
  "$HOME/.tmux/plugins/tpm/bin/install_plugins"
}

mac() {
  load_homebrew || die 'Homebrew is not installed.'
  _configure "$(brew --prefix tpm)/share/tpm"
}

linux() {
  _configure /usr/share/tmux-plugin-manager
}

configure_tmux "$1"
