#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
EXTENSIONS_DIR="$ROOT_DIR/vscode-extensions"
THEME_EXTENSION_DIR="$ROOT_DIR/custom-themes/vsce-package"

editor_clis=()

find_editor_clis() {
  local cli
  for cli in cursor codium code; do
    if command -v "$cli" >/dev/null 2>&1; then
      editor_clis+=("$(command -v "$cli")")
    fi
  done
}

install_vsix() {
  local vsix="$1"
  local cli

  if [[ "${#editor_clis[@]}" -eq 0 ]]; then
    printf 'No supported editor CLI found; built %s without installing it.\n' "$vsix"
    return
  fi

  for cli in "${editor_clis[@]}"; do
    "$cli" --install-extension "$vsix" --force
  done
}

build_extensions() {
  local candidate extension_dir vsix

  [[ -d "$EXTENSIONS_DIR" ]] || return
  for extension_dir in "$EXTENSIONS_DIR"/*; do
    [[ -f "$extension_dir/package.json" ]] || continue

    printf '\n==> Building %s\n' "$(basename "$extension_dir")"
    (
      cd "$extension_dir"
      npm ci
      npm run build
      npm run package:vsix
    )

    vsix=''
    for candidate in "$extension_dir"/*.vsix; do
      if [[ -f "$candidate" ]]; then
        vsix="$candidate"
        break
      fi
    done
    if [[ -z "$vsix" ]]; then
      printf 'No VSIX was produced in %s\n' "$extension_dir" >&2
      exit 1
    fi
    install_vsix "$vsix"
  done
}

build_theme() {
  local vsix="$THEME_EXTENSION_DIR/better-vscode-themes.vsix"

  [[ -f "$THEME_EXTENSION_DIR/package.json" ]] || return
  printf '\n==> Building custom theme extension\n'
  (
    cd "$THEME_EXTENSION_DIR"
    npm ci
    npx vsce package --out "$vsix"
  )
  install_vsix "$vsix"
}

main() {
  find_editor_clis
  build_extensions
  build_theme
}

main "$@"
