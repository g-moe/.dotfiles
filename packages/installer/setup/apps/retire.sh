#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
RETIRE_FILE="$INSTALLER_DIR/packages/retire.json"
. "$INSTALLER_DIR/lib/lib.sh"

retire_packages() {
  validate_retire_file "$RETIRE_FILE"
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  local name type

  load_homebrew || die 'Homebrew is not installed.'
  while IFS=$'\t' read -r type name; do
    if brew list "--$type" -1 | grep -Fxq "$name"; then
      brew uninstall "--$type" "$name"
    else
      log "$name is already absent."
    fi
  done < <(jq -r '.[] | select(.platform == "mac") | [.type, .name] | @tsv' "$RETIRE_FILE")
}

linux() {
  local name status

  while IFS= read -r name; do
    status="$(dpkg-query -W -f='${db:Status-Abbrev}' "$name" 2>/dev/null || true)"
    if [[ "$status" == ii* ]]; then
      sudo apt-get remove -y "$name"
    else
      log "$name is already absent."
    fi
  done < <(jq -r '.[] | select(.platform == "linux") | .name' "$RETIRE_FILE")
}

retire_packages "$1"
