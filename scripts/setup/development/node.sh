#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
. "$SCRIPTS_DIR/lib/lib.sh"

install_node() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_load_nvm() {
  export NVM_DIR="$HOME/.nvm"
  [[ -s "$NVM_DIR/nvm.sh" ]] || return 1
  set +u
  # shellcheck disable=SC1090
  . "$NVM_DIR/nvm.sh" --no-use
  set -u
}

_install() {
  local version

  version="$(tr -d '[:space:]' <"$ROOT_DIR/.nvmrc")"
  if ! _load_nvm; then
    PROFILE=/dev/null NVM_DIR="$HOME/.nvm" \
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh)"
    _load_nvm || die 'NVM did not become available.'
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
