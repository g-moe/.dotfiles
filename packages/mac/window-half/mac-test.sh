#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CORE_SOURCE="$SCRIPT_DIR/Sources/mac-WindowHalfCore.swift"
MAIN_SOURCE="$SCRIPT_DIR/Sources/mac-main.swift"
TEST_SOURCE="$SCRIPT_DIR/Tests/mac-WindowHalfCoreTests.swift"
TEST_BINARY_PATH="$(mktemp "${TMPDIR:-/tmp}/window-half-tests.XXXXXX")"
trap 'rm -f -- "$TEST_BINARY_PATH"' EXIT

/usr/bin/swiftc -typecheck "$CORE_SOURCE" "$MAIN_SOURCE"
/usr/bin/swiftc "$CORE_SOURCE" "$TEST_SOURCE" -o "$TEST_BINARY_PATH"
"$TEST_BINARY_PATH"
