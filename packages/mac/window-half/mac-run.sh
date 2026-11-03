#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="$HOME/Library/Caches/dotfiles/window-half"
BINARY_PATH="$CACHE_DIR/mac-window-half"
CORE_SOURCE="$SCRIPT_DIR/Sources/mac-WindowHalfCore.swift"
MAIN_SOURCE="$SCRIPT_DIR/Sources/mac-main.swift"

if [[ ! -x "$BINARY_PATH" ||
  "$CORE_SOURCE" -nt "$BINARY_PATH" ||
  "$MAIN_SOURCE" -nt "$BINARY_PATH" ]]; then
  mkdir -p "$CACHE_DIR"

  BUILD_PATH="$(mktemp "$CACHE_DIR/mac-window-half.XXXXXX")"
  trap 'rm -f -- "$BUILD_PATH"' EXIT

  /usr/bin/swiftc "$CORE_SOURCE" "$MAIN_SOURCE" -o "$BUILD_PATH"
  mv -f -- "$BUILD_PATH" "$BINARY_PATH"
fi

"$BINARY_PATH" "$@"
