#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib.sh"

configure_voice_assistant() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  defaults write com.apple.assistant.support 'Assistant Enabled' -bool false
  defaults write com.apple.Siri StatusMenuVisible -bool false
  defaults write com.apple.Siri UserHasDeclinedEnable -bool true
  defaults write com.apple.assistant.support 'Siri Data Sharing Opt-In Status' -int 2
  defaults write com.apple.SetupAssistant DidSeeSiriSetup -bool true
  silent killall Siri || true
}

linux() {
  log 'Ubuntu has no built-in voice assistant enabled.'
}

configure_voice_assistant "$1"
