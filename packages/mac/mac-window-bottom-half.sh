#!/usr/bin/env bash

# @raycast.schemaVersion 1
# @raycast.title Bottom Half
# @raycast.mode silent

# @raycast.icon ⬇️
# @raycast.packageName Window Tools
# @raycast.description Fit the focused window below the display's physical midpoint.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec /bin/bash "$SCRIPT_DIR/window-half/mac-run.sh" bottom "$@"
