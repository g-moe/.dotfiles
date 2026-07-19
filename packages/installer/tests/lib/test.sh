#!/usr/bin/env bash

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER_DIR="$(cd "$TESTS_DIR/.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
BASH_LIB_DIR="$ROOT_DIR/packages/lib/bash"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

expect_file_contains() {
  local file="$1"
  local text="$2"
  local message="$3"

  grep -Fq -- "$text" "$file" || fail "$message"
}
