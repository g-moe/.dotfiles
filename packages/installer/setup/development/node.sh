#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_node() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_install() {
  local version

  version="$(tr -d '[:space:]' <"$ROOT_DIR/.nvmrc")"
  if ! load_nvm; then
    # NVM refuses a missing custom NVM_DIR when XDG_CONFIG_HOME is set.
    mkdir -p "$HOME/.nvm"
    PROFILE=/dev/null NVM_DIR="$HOME/.nvm" \
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh)"
    load_nvm || die 'NVM did not become available.'
  fi
  set +u
  nvm install "$version"
  nvm alias default "$version"
  nvm use "$version"
  set -u
  (cd "$ROOT_DIR" && npm ci)
}

mac() {
  _install
}

linux() {
  _install
}

install_node "$1"
