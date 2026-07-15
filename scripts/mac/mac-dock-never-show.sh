#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

. "$LIB_DIR/lib.sh"

enable_dock_never_show() {
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-delay -float 999
  defaults write com.apple.dock autohide-time-modifier -float 0

  log 'Dock configured to stay hidden.'
}

disable_dock_never_show() {
  silent defaults delete com.apple.dock autohide-delay || true
  silent defaults delete com.apple.dock autohide-time-modifier || true

  log 'Dock hidden-delay override removed.'
}

main() {
  local choice

  choice="$(ask_choice 'Dock visibility:' 'Skip' 'Never show Dock' 'Undo never-show override')"

  case "$choice" in
    0)
      log 'Skipping Dock visibility changes.'
      return
      ;;
    1)
      enable_dock_never_show
      ;;
    2)
      disable_dock_never_show
      ;;
  esac

  silent killall Dock || true
}

main "$@"
