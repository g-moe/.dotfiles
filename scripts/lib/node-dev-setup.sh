#!/usr/bin/env bash

load_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    return 0
  fi

  log_info "Loading nvm from $NVM_DIR/nvm.sh"

  local restore_nounset=0
  if [[ "$-" == *u* ]]; then
    restore_nounset=1
    set +u
  fi

  # shellcheck disable=SC1090
  if ! . "$NVM_DIR/nvm.sh"; then
    if [[ "$restore_nounset" -eq 1 ]]; then
      set -u
    fi
    log_error "Could not load nvm from $NVM_DIR/nvm.sh"
    return 1
  fi

  if [[ "$restore_nounset" -eq 1 ]]; then
    set -u
  fi
}

node_major_version() {
  node --version | sed -E 's/^v([0-9]+).*/\1/'
}

install_nvm() {
  load_nvm
  if has_command nvm; then
    log_info 'nvm already installed.'
    return
  fi

  log_info 'Installing nvm...'
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  load_nvm

  if ! has_command nvm; then
    log_error 'nvm install completed, but nvm is not available in this shell.'
    log_error 'Open a new terminal and run: nvm install --lts'
    exit 1
  fi

  log_info 'nvm installed.'
}

node_dev_setup() {
  install_nvm

  if has_command node && has_command npm && [[ "$(node_major_version)" == '24' ]]; then
    log_info 'Node.js 24 and npm already installed.'
    return
  fi

  log_info 'Installing Node.js 24 LTS with nvm...'
  nvm install 24
  nvm alias default 24
  nvm use 24
  log_info 'Node.js and npm installed.'
}
