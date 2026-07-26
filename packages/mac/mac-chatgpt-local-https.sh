#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Chat GPT
# @raycast.mode silent

# Optional parameters:
# @raycast.icon /Applications/ChatGPT.app/Contents/Resources/icon-chatgpt.icns
# @raycast.packageName Developer Tools
# @raycast.description Open ChatGPT with certificate checks disabled for local development.

set -euo pipefail

# OTHER OPTIONS
#
# Automatically open DevTools for each browser tab.
# Limitation: DevTools opens in a separate window. This flag cannot dock it
# inside Codex or force Electron's "bottom" mode.
# DEVTOOLS_FLAG='--auto-open-devtools-for-tabs'
DEVTOOLS_FLAG=''

APP_PATH='/Applications/ChatGPT.app'
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/ChatGPT"
APP_BUNDLE_ID='com.openai.codex'
INSECURE_FLAG='--ignore-certificate-errors'

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

if ps axww -o command= | awk \
  -v executable="$APP_EXECUTABLE" \
  -v insecure_flag="$INSECURE_FLAG" \
  -v devtools_flag="$DEVTOOLS_FLAG" '
  $1 == executable {
    for (field = 2; field <= NF; field++) {
      if ($field == insecure_flag) insecure_found = 1
      if ($field == devtools_flag) devtools_found = 1
    }
  }
  END { exit !(insecure_found && (devtools_flag == "" || devtools_found)) }
'; then
  open -a ChatGPT
  exit 0
fi

if pgrep -x ChatGPT >/dev/null; then
  osascript -e 'quit app "ChatGPT"'

  for _ in {1..100}; do
    pgrep -x ChatGPT >/dev/null || break
    sleep 0.1
  done

  if pgrep -x ChatGPT >/dev/null; then
    osascript -e 'display notification "Quit ChatGPT manually, then run this command again." with title "ChatGPT Local HTTPS"'
    exit 1
  fi
fi

APP_FLAGS=("$INSECURE_FLAG")
[[ -z "$DEVTOOLS_FLAG" ]] || APP_FLAGS+=("$DEVTOOLS_FLAG")

open -na "$APP_PATH" --args "${APP_FLAGS[@]}"
