#!/usr/bin/env bash

set -euo pipefail

ZEN_APP_NAME="${ZEN_APP_NAME:-Zen}"
ZEN_SPACE_NUMBER="${ZEN_SPACE_NUMBER:-}"
ZEN_TAB_NUMBER="${ZEN_TAB_NUMBER:-1}"

if [[ -z "$ZEN_SPACE_NUMBER" ]]; then
  echo "Missing ZEN_SPACE_NUMBER"
  exit 1
fi

ZEN_SPACE_NUMBER="$(xargs <<<"$ZEN_SPACE_NUMBER")"

if ! [[ "$ZEN_SPACE_NUMBER" =~ ^[1-9]$ ]]; then
  echo "ZEN_SPACE_NUMBER must be 1-9"
  exit 1
fi

ZEN_TAB_NUMBER="$(xargs <<<"$ZEN_TAB_NUMBER")"

if ! [[ "$ZEN_TAB_NUMBER" =~ ^[1-9]$ ]]; then
  echo "ZEN_TAB_NUMBER must be 1-9"
  exit 1
fi

osascript - "$ZEN_APP_NAME" "$ZEN_SPACE_NUMBER" "$ZEN_TAB_NUMBER" <<'APPLESCRIPT' >/dev/null
on run argv
  set appName to item 1 of argv
  set spaceIndex to item 2 of argv as integer
  set tabIndex to item 3 of argv as integer
  set wasRunning to false

  tell application appName
    set wasRunning to running
    if wasRunning is false then launch
    activate
  end tell

  my waitUntilAppReady(appName)


  my switchWorkspaceByShortcut(appName, spaceIndex)
  if wasRunning is false then delay 0.2
  my switchTabByShortcut(appName, tabIndex)

end run

on waitUntilAppReady(appName)
  tell application "System Events"
    repeat 20 times
      if (exists process appName) then
        tell process appName
          if frontmost is true and (count of windows) is greater than 0 then return
        end tell
      end if
      delay 0.1
    end repeat
  end tell
end waitUntilAppReady

on switchWorkspaceByShortcut(appName, spaceIndex)
  tell application "System Events"
    tell process appName
      set frontmost to true
    end tell

    key code my keyCodeForDigit(spaceIndex) using {control down, shift down}
  end tell
end switchWorkspaceByShortcut

on switchTabByShortcut(appName, tabIndex)
  tell application "System Events"
    tell process appName
      set frontmost to true
    end tell

    key code my keyCodeForDigit(tabIndex) using {control down}
  end tell
end switchTabByShortcut

on keyCodeForDigit(digit)
  return item (digit as integer) of {18, 19, 20, 21, 23, 22, 26, 28, 25}
end keyCodeForDigit
APPLESCRIPT
