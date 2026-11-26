#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle Wave Windows
# @raycast.mode silent

# Optional parameters:
# @raycast.icon /Applications/Wave.app/Contents/Resources/Wave.icns
# @raycast.packageName Window Tools

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN="${TMPDIR:-/tmp}/wave-window-toggle"
CORE="$SCRIPT_DIR/window-toggle/Sources/mac-WindowToggleCore.swift"
MAIN="$SCRIPT_DIR/window-toggle/Sources/mac-main.swift"

if [[ ! -x "$BIN" || "$CORE" -nt "$BIN" || "$MAIN" -nt "$BIN" ]]; then
  /usr/bin/swiftc "$CORE" "$MAIN" -o "$BIN"
fi

"$BIN" \
  "Wave" \
  "dev.wave.browser" \
  "wave-window-toggle.state"
