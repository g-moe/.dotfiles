#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib.sh"

configure_headless_access() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  local status
  status="$(fdesetup status 2>/dev/null || true)"
  if [[ "$status" == *'FileVault is On.'* ]]; then
    log 'FileVault blocks remote access after a cold boot until someone unlocks the Mac.'
    if ask_binary 'Disable FileVault for headless access?'; then
      sudo fdesetup disable
    fi
  fi
}

linux() {
  local root_source root_type
  root_source="$(findmnt -no SOURCE /)"
  root_type="$(lsblk -no TYPE "$root_source" 2>/dev/null || true)"
  if [[ "$root_type" == crypt ]]; then
    log 'Disk encryption blocks remote access after a cold boot until someone unlocks Ubuntu.'
  fi
}

configure_headless_access "$1"
