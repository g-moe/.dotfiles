#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Finder
# @raycast.mode silent

# Optional parameters:
# @raycast.icon /System/Library/CoreServices/Finder.app/Contents/Resources/Finder.icns
# @raycast.packageName Window Tools

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../lib/bash/lib.sh"

# Bring Finder forward with a focused window, then run Raycast's built-in Window Management "Almost Maximize" command.
# Default deeplink: raycast://extensions/raycast/window-management/almost-maximize
if ! silent osascript -e 'tell application "System Events" to tell process "Finder" to count windows'; then
  silent osascript -e 'display notification "Grant Raycast access in Privacy & Security > Accessibility, then run again." with title "Finder Almost Maximize"'
  exit 0
fi

DEEPLINK="${RAYCAST_ALMOST_MAXIMIZE_DEEPLINK:-raycast://extensions/raycast/window-management/almost-maximize?launchType=background}"

if ! osascript >/dev/null <<'APPLESCRIPT'
tell application "Finder"
    activate
    reopen
end tell

tell application "System Events"
    repeat 20 times
        try
            tell process "Finder"
                set frontmost to true
                if (count of windows) > 0 then
                    perform action "AXRaise" of window 1
                    set value of attribute "AXMain" of window 1 to true
                    exit repeat
                end if
            end tell
        end try
        delay 0.05
    end repeat
end tell

APPLESCRIPT
then
  silent osascript -e 'display notification "Could not focus a Finder window." with title "Finder Almost Maximize"'
  exit 0
fi

/usr/bin/open -g "$DEEPLINK"

exit 0
