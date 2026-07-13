#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
architecture_reads=''
failed_skip_returns=''

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

while IFS= read -r strategy; do
  relative="${strategy#"$SCRIPTS_DIR/setup/"}"
  registrations="$(grep -Ec "run_strategy '[^']+' $relative$" "$SCRIPTS_DIR/install.sh" || true)"
  [[ "$registrations" -eq 1 ]] ||
    fail "$relative is registered $registrations times; expected once"
  grep -Fq 'case "$1" in' "$strategy" || fail "$strategy has no OS switch"
  grep -Eq '^mac\(\)[[:space:]]*\{' "$strategy" || fail "$strategy has no mac() function"
  grep -Eq '^linux\(\)[[:space:]]*\{' "$strategy" || fail "$strategy has no linux() function"
  bash -n "$strategy"
done < <(find "$SCRIPTS_DIR/setup" -type f -name '*.sh' | sort)

while IFS= read -r strategy; do
  [[ -f "$SCRIPTS_DIR/setup/$strategy" ]] ||
    fail "install.sh registers missing setup file: $strategy"
done < <(sed -nE "s/.*run_strategy '[^']+' ([^[:space:]]+)$/\1/p" "$SCRIPTS_DIR/install.sh")

grep -Fq 'LINUX_ARCH="$(dpkg --print-architecture)"' \
  "$SCRIPTS_DIR/lib/lib-install.sh" ||
  fail 'lib-install.sh does not detect the Linux CPU architecture'
architecture_reads="$(find "$SCRIPTS_DIR/setup" -type f -name '*.sh' \
  -exec grep -nH 'dpkg --print-architecture' {} + || true)"
if [[ -n "$architecture_reads" ]]; then
  printf '%s\n' "$architecture_reads" >&2
  fail 'setup files must use the exported LINUX_ARCH value'
fi
failed_skip_returns="$(find "$SCRIPTS_DIR/setup" -type f -name '*.sh' \
  -exec grep -nHE '\|\| return[[:space:]]*$' {} + || true)"
if [[ -n "$failed_skip_returns" ]]; then
  printf '%s\n' "$failed_skip_returns" >&2
  fail 'a skipped choice must use return 0'
fi

bash -n "$SCRIPTS_DIR/install.sh"
bash -n "$SCRIPTS_DIR/lib/lib-install.sh"

[[ ! -e "$SCRIPTS_DIR/mac-install.sh" ]] || fail 'old Mac installer still exists'
[[ ! -e "$SCRIPTS_DIR/linux-install.sh" ]] || fail 'old Linux installer still exists'

if grep -RIEq 'linuxbrew|migrat(e|ion)|backwards?[ -]?compat' \
  "$SCRIPTS_DIR/install.sh" "$SCRIPTS_DIR/lib" "$SCRIPTS_DIR/setup"; then
  fail 'installer contains an old-system migration or compatibility path'
fi

printf 'Strategy shape passed for every setup file.\n'
