#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Zoom All Windows
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🪟
# @raycast.packageName Window Tools

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../lib/lib.sh"

# Use Raycast's built-in Window Management "Maximize" command on every visible standard window.
# Default deeplink: raycast://extensions/raycast/window-management/maximize
if ! silent osascript -e 'tell application "System Events" to tell process "Finder" to count windows'; then
  silent osascript -e 'display notification "Grant Raycast access in Privacy & Security > Accessibility, then run again." with title "Zoom All Windows"'
  exit 0
fi

DEEPLINK="${RAYCAST_MAXIMIZE_DEEPLINK:-raycast://extensions/raycast/window-management/maximize?launchType=background}"

actions=$(RAYCAST_MAXIMIZE_DEEPLINK="$DEEPLINK" osascript 2>/dev/null <<'APPLESCRIPT'
set maximizeDeeplink to system attribute "RAYCAST_MAXIMIZE_DEEPLINK"
set actionCount to 0

tell application "System Events"
    repeat with p in (application processes whose background only is false and visible is true)
        set ws to {}
        try
            set ws to windows of p
        end try

        repeat with w in ws
            set shouldMaximize to true

            try
                if (value of attribute "AXMinimized" of w) is true then set shouldMaximize to false
            end try

            try
                set subroleValue to value of attribute "AXSubrole" of w
                if subroleValue is not missing value and subroleValue is not "AXStandardWindow" then set shouldMaximize to false
            end try

            if shouldMaximize is true then
                try
                    set frontmost of p to true
                end try
                try
                    perform action "AXRaise" of w
                end try
                try
                    set value of attribute "AXMain" of w to true
                end try
                try
                    set value of attribute "AXFocused" of w to true
                end try

                delay 0.12

                try
                    do shell script "open -g " & quoted form of maximizeDeeplink
                    set actionCount to actionCount + 1
                end try

                delay 0.06
            end if
        end repeat
    end repeat
end tell

return actionCount
APPLESCRIPT
)

if [ $? -ne 0 ]; then
  silent osascript -e 'display notification "Window automation failed while applying Raycast Maximize." with title "Zoom All Windows"'
  exit 0
fi

if ! [ "${actions:-0}" -gt 0 ] 2>/dev/null; then
  silent osascript -e 'display notification "No windows were targeted." with title "Zoom All Windows"'
fi

exit 0
