#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
LIB_DIR="$SCRIPTS_DIR/lib"

. "$LIB_DIR/lib-logging.sh"
. "$LIB_DIR/lib-utils.sh"
. "$LIB_DIR/lib-runtime.sh"

enable_install_error_trap

install_nvm() {
  if load_nvm && command -v nvm >/dev/null 2>&1; then
    log_info 'nvm already installed.'
    return
  fi

  log_info 'Installing nvm...'
  PROFILE=/dev/null NVM_DIR="${NVM_DIR:-$HOME/.nvm}" \
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh)"

  if ! load_nvm || ! command -v nvm >/dev/null 2>&1; then
    log_error 'nvm installation completed, but nvm is unavailable.'
    return 1
  fi

  log_info 'nvm installed without changing a shell profile.'
}

install_node() {
  local version
  version="$(node_version_from_file "$ROOT_DIR/.nvmrc")"

  log_info "Installing and selecting Node.js $version with nvm..."
  run_nvm install "$version"
  run_nvm alias default "$version"
  use_node_from_file "$ROOT_DIR/.nvmrc"
  log_info "Node.js $(node --version) and npm $(npm --version) are active."
}

install_root_dependencies() {
  log_info 'Installing root Node dependencies with npm ci...'
  (
    cd "$ROOT_DIR"
    npm ci
  )
  log_info 'Root Node dependencies installed.'
}

main() {
  if [[ "$(id -u)" -eq 0 ]]; then
    log_error 'Do not run Node setup as root.'
    exit 1
  fi

  if [[ -z "${HOME:-}" ]]; then
    log_error 'HOME is not set; cannot configure Node.js.'
    exit 1
  fi

  run_step 'Install nvm' install_nvm
  run_step 'Install Node.js' install_node
  run_step 'Install Root Node Dependencies' install_root_dependencies
}

main "$@"
