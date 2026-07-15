#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title t3-chat
# @raycast.mode silent

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export ZEN_APP_NAME="${ZEN_APP_NAME:-Zen}"
export ZEN_SPACE_NUMBER="${ZEN_SPACE_NUMBER:-1}"
export ZEN_TAB_NUMBER="${ZEN_TAB_NUMBER:-1}"

"$SCRIPT_DIR/mac-main.sh"
