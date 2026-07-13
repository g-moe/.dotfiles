#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

configure_tmux() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_configure() {
  local tpm_source="$1"

  link_config "$ROOT_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
  link_config "$tpm_source" "$HOME/.tmux/plugins/tpm"
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
