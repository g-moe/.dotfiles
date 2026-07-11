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
  set workspaceKey to spaceIndex as text
  set workspaceKeyCode to my keyCodeForKey(workspaceKey)

  tell application "System Events"
    tell process appName
      set frontmost to true
    end tell

    key code workspaceKeyCode using {control down, shift down}
  end tell
end switchWorkspaceByShortcut

on switchTabByShortcut(appName, tabIndex)
  set tabKey to tabIndex as text
  set tabKeyCode to my keyCodeForKey(tabKey)

  tell application "System Events"
    tell process appName
      set frontmost to true
    end tell

    key code tabKeyCode using {control down}
  end tell
end switchTabByShortcut

on keyCodeForKey(keyName)
  set k to (keyName as text)
  if k is "a" then return 0
  if k is "s" then return 1
  if k is "d" then return 2
  if k is "f" then return 3
  if k is "h" then return 4
  if k is "g" then return 5
  if k is "z" then return 6
  if k is "x" then return 7
  if k is "c" then return 8
  if k is "v" then return 9
  if k is "b" then return 11
  if k is "q" then return 12
  if k is "w" then return 13
  if k is "e" then return 14
  if k is "r" then return 15
  if k is "y" then return 16
  if k is "t" then return 17
  if k is "1" then return 18
  if k is "2" then return 19
  if k is "3" then return 20
  if k is "4" then return 21
  if k is "6" then return 22
  if k is "5" then return 23
  if k is "=" then return 24
  if k is "9" then return 25
  if k is "7" then return 26
  if k is "-" then return 27
  if k is "8" then return 28
  if k is "0" then return 29
  if k is "]" then return 30
  if k is "o" then return 31
  if k is "u" then return 32
  if k is "[" then return 33
  if k is "i" then return 34
  if k is "p" then return 35
  if k is "return" then return 36
  if k is "l" then return 37
  if k is "j" then return 38
  if k is "'" then return 39
  if k is "k" then return 40
  if k is ";" then return 41
  if k is "\\" then return 42
  if k is "," then return 43
  if k is "/" then return 44
  if k is "n" then return 45
  if k is "m" then return 46
  if k is "." then return 47
  if k is "tab" then return 48
  if k is "space" then return 49
  if k is "`" then return 50
  if k is "delete" then return 51
  if k is "escape" then return 53
  if k is "command" then return 55
  if k is "shift" then return 56
  if k is "capslock" then return 57
  if k is "option" then return 58
  if k is "control" then return 59
  if k is "rightshift" then return 60
  if k is "rightoption" then return 61
  if k is "rightcontrol" then return 62
  if k is "fn" then return 63
  if k is "f17" then return 64
  if k is "keypaddecimal" then return 65
  if k is "keypadmultiply" then return 67
  if k is "keypadplus" then return 69
  if k is "keypadclear" then return 71
  if k is "volup" then return 72
  if k is "voldown" then return 73
  if k is "mute" then return 74
  if k is "keypaddivide" then return 75
  if k is "keypadenter" then return 76
  if k is "keypadminus" then return 78
  if k is "f18" then return 79
  if k is "f19" then return 80
  if k is "keypadequals" then return 81
  if k is "keypad0" then return 82
  if k is "keypad1" then return 83
  if k is "keypad2" then return 84
  if k is "keypad3" then return 85
  if k is "keypad4" then return 86
  if k is "keypad5" then return 87
  if k is "keypad6" then return 88
  if k is "keypad7" then return 89
  if k is "f20" then return 90
  if k is "keypad8" then return 91
  if k is "keypad9" then return 92
  if k is "jiskana" then return 93
  if k is "jisunderscore" then return 94
  if k is "jiskeypadcomma" then return 95
  if k is "f5" then return 96
  if k is "f6" then return 97
  if k is "f7" then return 98
  if k is "f3" then return 99
  if k is "f8" then return 100
  if k is "f9" then return 101
  if k is "jiseisu" then return 102
  if k is "f11" then return 103
  if k is "jisyen" then return 106
  if k is "f13" then return 105
  if k is "f16" then return 106
  if k is "f14" then return 107
  if k is "f10" then return 109
  if k is "f12" then return 111
  if k is "f15" then return 113
  if k is "help" then return 114
  if k is "home" then return 115
  if k is "pageup" then return 116
  if k is "forwarddelete" then return 117
  if k is "f4" then return 118
  if k is "end" then return 119
  if k is "f2" then return 120
  if k is "pagedown" then return 121
  if k is "f1" then return 122
  if k is "left" then return 123
  if k is "right" then return 124
  if k is "down" then return 125
  if k is "up" then return 126
  error "Unsupported key: " & k
end keyCodeForKey
APPLESCRIPT
