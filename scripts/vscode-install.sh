#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXTENSIONS_DIR="$ROOT_DIR/vscode-extensions"
THEME_EXTENSION_DIR="$ROOT_DIR/custom-themes/vsce-package"

if [ ! -d "$EXTENSIONS_DIR" ]; then
	printf 'No vscode-extensions directory found at %s\n' "$EXTENSIONS_DIR"
	exit 0
fi

installed_any=false

for extension_dir in "$EXTENSIONS_DIR"/*; do
	if [ ! -d "$extension_dir" ] || [ ! -f "$extension_dir/package.json" ]; then
		continue
	fi

	installed_any=true
	printf '\n==> Installing %s\n' "$(basename "$extension_dir")"
	(cd "$extension_dir" && npm install && npm run build && npm run install:cursor --if-present && npm run install:codium --if-present)
done

if [ "$installed_any" = false ]; then
	printf 'No installable VS Code extensions found in %s\n' "$EXTENSIONS_DIR"
fi

if [ -f "$THEME_EXTENSION_DIR/package.json" ]; then
	printf '\n==> Installing custom theme extension\n'
	(cd "$THEME_EXTENSION_DIR" && npm install && npm run install:cursor --if-present && npm run install:codium --if-present)
fi
