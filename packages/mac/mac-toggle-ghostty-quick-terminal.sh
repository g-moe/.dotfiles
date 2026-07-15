#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Ghostty Quick Terminal
# @raycast.mode silent

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../lib/bash/lib.sh"

silent osascript -e 'if application "Ghostty" is not running then tell application "Ghostty" to launch' \
  -e 'tell application "System Events" to tell process "Ghostty" to click menu item "Quick Terminal" of menu "View" of menu bar 1'
exit 0
