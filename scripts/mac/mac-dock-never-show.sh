#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

. "$LIB_DIR/lib-logging.sh"
. "$LIB_DIR/lib-interactive.sh"
. "$LIB_DIR/lib-utils.sh"

enable_install_error_trap

enable_dock_never_show() {
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-delay -float 999
  defaults write com.apple.dock autohide-time-modifier -float 0

  log_info 'Dock configured to stay hidden.'
}

disable_dock_never_show() {
  silent defaults delete com.apple.dock autohide-delay || true
  silent defaults delete com.apple.dock autohide-time-modifier || true

  log_info 'Dock hidden-delay override removed.'
}

main() {
  local choice

  choice="$(interactive_select 'Dock visibility:' 'Skip' 'Never show Dock' 'Undo never-show override')"

  case "$choice" in
    0)
      log_info 'Skipping Dock visibility changes.'
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
