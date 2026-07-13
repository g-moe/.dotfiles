#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

while IFS= read -r strategy; do
  grep -Fq 'case "$1" in' "$strategy" || fail "$strategy has no OS switch"
  grep -Eq '^mac\(\)[[:space:]]*\{' "$strategy" || fail "$strategy has no mac() function"
  grep -Eq '^linux\(\)[[:space:]]*\{' "$strategy" || fail "$strategy has no linux() function"
  bash -n "$strategy"
done < <(find "$SCRIPTS_DIR/setup" -type f -name '*.sh' | sort)

bash -n "$SCRIPTS_DIR/install.sh"
bash -n "$SCRIPTS_DIR/lib/lib-install.sh"

[[ ! -e "$SCRIPTS_DIR/mac-install.sh" ]] || fail 'old Mac installer still exists'
[[ ! -e "$SCRIPTS_DIR/linux-install.sh" ]] || fail 'old Linux installer still exists'

if grep -RIEq 'linuxbrew|migrat(e|ion)|backwards?[ -]?compat' \
  "$SCRIPTS_DIR/install.sh" "$SCRIPTS_DIR/lib" "$SCRIPTS_DIR/setup"; then
  fail 'installer contains an old-system migration or compatibility path'
fi

printf 'Strategy shape passed for every setup file.\n'
