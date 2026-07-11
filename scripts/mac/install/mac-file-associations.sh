#!/usr/bin/env bash
set -euo pipefail

VSCODIUM_BUNDLE_ID="com.vscodium"

if ! command -v duti >/dev/null 2>&1; then
    echo "duti is required; run scripts/mac-install.sh first." >&2
    exit 1
fi

echo "Setting VSCodium as default editor for code and config files..."

set_handler() {
    local ext="$1"

    # Try setting via extension first (works for well-known UTIs)
    if duti -s "$VSCODIUM_BUNDLE_ID" "$ext" all 2>/dev/null; then
        return 0
    fi

    # Try editor role fallback
    if duti -s "$VSCODIUM_BUNDLE_ID" "$ext" editor 2>/dev/null; then
        return 0
    fi

    # For dynamic UTIs, discover the UTI from a temp file and use that
    local tmpfile
    tmpfile="$(mktemp "/tmp/duti-XXXXXX.${ext#.}")"
    local uti=""

    if command -v mdls >/dev/null 2>&1; then
        uti="$(mdls -name kMDItemContentType -raw "$tmpfile" 2>/dev/null || true)"
    fi

    rm -f "$tmpfile"

    if [[ -n "$uti" && "$uti" != "(null)" && "$uti" != "*" ]]; then
        if duti -s "$VSCODIUM_BUNDLE_ID" "$uti" all 2>/dev/null; then
            return 0
        fi

        if duti -s "$VSCODIUM_BUNDLE_ID" "$uti" editor 2>/dev/null; then
            return 0
        fi
    fi

    echo "  Skipped $ext (unable to bind UTI)"
    return 1
}

# Code files
set_handler .ts
set_handler .tsx
set_handler .js
set_handler .jsx
set_handler .mjs
set_handler .cjs
set_handler .py
set_handler .rs
set_handler .go
set_handler .swift
set_handler .zig
set_handler .c
set_handler .h
set_handler .cpp
set_handler .hpp
set_handler .css
set_handler .scss
set_handler .html
set_handler .vue
set_handler .svelte

# Config files
set_handler .json
set_handler .yaml
set_handler .yml
set_handler .toml
set_handler .env
set_handler .ini
set_handler .conf
set_handler .cfg

# Shell/scripts
set_handler .sh
set_handler .zsh
set_handler .bash
set_handler .fish

# Docs/markup
set_handler .md
set_handler .mdx
set_handler .txt

echo "Done! File associations updated."
