#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../../lib"

. "$LIB_DIR/lib-logging.sh"

enable_install_error_trap

run_setup() {
  local label="$1"
  local script_name="$2"
  shift 2
  run_step "$label" bash "$SCRIPT_DIR/$script_name" "$@"
}

main() {
  run_setup 'Install Homebrew' shared-homebrew-setup.sh
  run_setup 'Install applications' shared-apps-setup.sh
  run_setup 'Show machine name in menu bar' shared-machine-name-menu-bar.sh
  run_setup 'Set up Node.js' shared-node-setup.sh
  run_setup 'Set up Zsh' shared-zsh-setup.sh
  run_setup 'Set up tmux' shared-tmux-setup.sh
  run_setup 'Install Tailscale' shared-tailscale-setup.sh install
}

main "$@"
