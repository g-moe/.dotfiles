#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

install_vscodium_extensions() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_load_node() {
  export NVM_DIR="$HOME/.nvm"
  set +u
  # shellcheck disable=SC1090
  . "$NVM_DIR/nvm.sh"
  nvm use --silent 24
  set -u
}

_install() {
  local extension_dir vsix

  _load_node
  for extension_dir in "$ROOT_DIR"/vscode-extensions/*; do
    [[ -f "$extension_dir/package.json" ]] || continue
    (
      cd "$extension_dir"
      npm ci
      npm run build
      npm run package:vsix
    )
    vsix="$(find "$extension_dir" -maxdepth 1 -name '*.vsix' -print -quit)"
    [[ -n "$vsix" ]] || die "No extension was built in $extension_dir"
    codium --install-extension "$vsix" --force
  done

  extension_dir="$ROOT_DIR/custom-themes/vsce-package"
  (
    cd "$extension_dir"
    npm ci
    npx vsce package --out better-vscode-themes.vsix
  )
  codium --install-extension "$extension_dir/better-vscode-themes.vsix" --force
}

mac() {
  load_homebrew || die 'Homebrew is not installed.'
  _install
}

linux() {
  _install
}

install_vscodium_extensions "$1"
