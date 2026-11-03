#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_run_it() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_install() {
  activate_repo_node "$ROOT_DIR" || die 'Run --development first so Node.js is available.'
  if [[ ! -x "$ROOT_DIR/node_modules/.bin/tsc" ]]; then
    (cd "$ROOT_DIR" && npm ci)
  fi
  "$ROOT_DIR/node_modules/.bin/tsc" -p "$ROOT_DIR/packages/run-it/tsconfig.json"
  chmod +x "$ROOT_DIR/packages/run-it/dist/cli/main.js"
  mkdir -p "$HOME/.local/bin"
  safe_symlink_group 'Run-it CLI' \
    "$ROOT_DIR/packages/run-it/dist/cli/main.js" "$HOME/.local/bin/run-it"
}

mac() {
  _install
}

linux() {
  _install
}

install_run_it "$1"
