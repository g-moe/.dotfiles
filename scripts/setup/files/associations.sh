#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

configure_file_associations() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_extensions() {
  printf '%s\n' \
    ts tsx js jsx mjs cjs py rs go swift zig c h cpp hpp css scss html vue svelte \
    json yaml yml toml env ini conf cfg sh zsh bash fish md mdx txt
}

_mac_handler() {
  local extension="$1"
  local temporary_file uti

  duti -s com.vscodium "$extension" all 2>/dev/null && return
  duti -s com.vscodium "$extension" editor 2>/dev/null && return
  temporary_file="$(mktemp "${TMPDIR:-/tmp}/vscodium.XXXXXX.$extension")"
  uti="$(mdls -name kMDItemContentType -raw "$temporary_file" 2>/dev/null || true)"
  rm -f "$temporary_file"
  [[ -n "$uti" && "$uti" != '(null)' && "$uti" != '*' ]] || return
  duti -s com.vscodium "$uti" all 2>/dev/null || duti -s com.vscodium "$uti" editor
}

mac() {
  local extension
  while IFS= read -r extension; do
    _mac_handler "$extension"
  done < <(_extensions)
}

linux() {
  local extension mime_type temporary_file
  while IFS= read -r extension; do
    temporary_file="$(mktemp "${TMPDIR:-/tmp}/vscodium.XXXXXX.$extension")"
    mime_type="$(xdg-mime query filetype "$temporary_file")"
    rm -f "$temporary_file"
    [[ -n "$mime_type" ]] && xdg-mime default codium.desktop "$mime_type"
  done < <(_extensions)
}

configure_file_associations "$1"
