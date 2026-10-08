#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title T3 Code (Alpha)
# @raycast.mode silent

# Optional parameters:
# @raycast.icon /Applications/T3 Code (Alpha).app/Contents/Resources/icon.icns
# @raycast.packageName Developer Tools
# @raycast.description Open T3 Code (Alpha) with certificate checks disabled for local development.

set -euo pipefail

APP_PATH='/Applications/T3 Code (Alpha).app'
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/T3 Code (Alpha)"
APP_BUNDLE_ID='com.t3tools.t3code'
APP_PROCESS_PATTERN='T3 Code \(Alpha\)'
INSECURE_FLAG='--ignore-certificate-errors'

# Hide the app if it is already in front.
if [[ "$(
  osascript -l JavaScript -e "
    ObjC.import('AppKit');
    const app = $.NSWorkspace.sharedWorkspace.frontmostApplication;
    if (ObjC.unwrap(app.bundleIdentifier) === '$APP_BUNDLE_ID') {
      app.hide;
      'hidden';
    } else {
      'show';
    }
  "
)" == 'hidden' ]]; then
  exit 0
fi

# Match the full executable path because the app name contains spaces.
if ps axww -o command= | awk \
  -v executable="$APP_EXECUTABLE" \
  -v insecure_flag="$INSECURE_FLAG" '
  $0 == executable || index($0, executable " ") == 1 {
    command = substr($0, length(executable) + 1)
    count = split(command, args, /[[:space:]]+/)

    for (field = 1; field <= count; field++) {
      if (args[field] == insecure_flag) insecure_found = 1
    }
  }
  END {
    exit !insecure_found
  }
'; then
  open -a "$APP_PATH"
  exit 0
fi

# Restart the app if its current process does not have the required flag.
if pgrep -x "$APP_PROCESS_PATTERN" >/dev/null; then
  osascript -e 'quit app "T3 Code (Alpha)"'

  for _ in {1..100}; do
    pgrep -x "$APP_PROCESS_PATTERN" >/dev/null || break
    sleep 0.1
  done

  if pgrep -x "$APP_PROCESS_PATTERN" >/dev/null; then
    osascript -e 'display notification "Quit T3 Code (Alpha) manually, then run this command again." with title "T3 Code Local HTTPS"'
    exit 1
  fi
fi

# Start a new process so the certificate flag takes effect.
open -na "$APP_PATH" --args "$INSECURE_FLAG"
