#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_apple_intelligence() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  defaults write com.apple.Siri AppleIntelligenceEnabled -bool false
  defaults write com.apple.Siri LLMEnable -bool false
}

linux() {
  log 'Debian has no built-in AI assistant enabled.'
}

configure_apple_intelligence "$1"
