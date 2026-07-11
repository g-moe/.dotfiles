#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../../lib"

. "$LIB_DIR/lib-logging.sh"
. "$LIB_DIR/lib-interactive.sh"
. "$LIB_DIR/lib-runtime.sh"
. "$LIB_DIR/lib-utils.sh"

enable_install_error_trap

install_cask() {
  local cask_name="$1"

  if brew_has_cask "$cask_name"; then
    log_info "$cask_name already installed."
    return
  fi

  log_info "Installing $cask_name..."
  brew install --cask "$cask_name"
  log_info "$cask_name installed."
}

install_nordvpn() {
  local choice
  choice="$(interactive_select 'Install NordVPN?' 'Skip' 'Install')"

  case "$choice" in
    0) log_info 'Skipping NordVPN install.' ;;
    1) install_cask nordvpn ;;
  esac
}

install_opencode_desktop() {
  if brew_has_cask opencode-desktop; then
    log_info 'opencode-desktop already installed.'
    return
  fi

  if [[ -d /Applications/OpenCode.app || -d "$HOME/Applications/OpenCode.app" ]]; then
    log_info 'OpenCode.app already present; skipping Homebrew install.'
    return
  fi

  install_cask opencode-desktop
}

main() {
  if ! load_homebrew || ! has_command brew; then
    log_error 'Homebrew is required to install optional Mac software.'
    exit 1
  fi

  run_step 'Install NordVPN' install_nordvpn
  run_step 'Install OpenCode Desktop' install_opencode_desktop
}

main "$@"
