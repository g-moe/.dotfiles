#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../../lib"
BREWFILE="$SCRIPT_DIR/shared-Brewfile"

. "$LIB_DIR/lib-logging.sh"
. "$LIB_DIR/lib-get-linux-or-mac.sh"
. "$LIB_DIR/lib-runtime.sh"
. "$LIB_DIR/lib-utils.sh"

enable_install_error_trap

install_homebrew_apps() {
  if ! load_homebrew || ! has_command brew; then
    log_error 'Homebrew is required to install applications.'
    return 1
  fi

  if [[ ! -f "$BREWFILE" ]]; then
    log_error "Missing Brewfile: $BREWFILE"
    return 1
  fi

  brew bundle install --no-upgrade --file="$BREWFILE"
}

mac() {
  install_homebrew_apps
}

linux() {
  install_homebrew_apps
  sudo apt-get update
  sudo apt-get install -y fonts-jetbrains-mono
}

main() {
  dispatch_linux_or_mac "$@"
}

main "$@"
