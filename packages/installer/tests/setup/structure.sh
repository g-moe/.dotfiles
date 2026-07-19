#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../lib/test.sh"

while IFS= read -r strategy; do
  relative="${strategy#"$INSTALLER_DIR/setup/"}"
  registrations="$(grep -Ec "run_strategy '[^']+' $relative$" "$INSTALLER_DIR/install.sh" || true)"
  [[ "$registrations" -eq 1 ]] ||
    fail "$relative is registered $registrations times; expected once"
  grep -Fq 'case "$1" in' "$strategy" || fail "$relative has no OS switch"
  grep -Eq '^mac\(\)[[:space:]]*\{' "$strategy" || fail "$relative has no mac()"
  grep -Eq '^linux\(\)[[:space:]]*\{' "$strategy" || fail "$relative has no linux()"
  bash -n "$strategy"
done < <(find "$INSTALLER_DIR/setup" -type f -name '*.sh' | sort)

while IFS= read -r strategy; do
  [[ -f "$INSTALLER_DIR/setup/$strategy" ]] ||
    fail "install.sh registers missing setup file: $strategy"
done < <(sed -nE "s/.*run_strategy '[^']+' ([^[:space:]]+)$/\1/p" "$INSTALLER_DIR/install.sh")

standalone_detect="$(find "$INSTALLER_DIR/setup" -type f -name '*.sh' \
  -exec grep -nH 'detect_os' {} + || true)"
[[ -z "$standalone_detect" ]] || fail 'setup files must not call detect_os'

architecture_reads="$(find "$INSTALLER_DIR/setup" -type f -name '*.sh' \
  -exec grep -nH 'dpkg --print-architecture' {} + || true)"
[[ -z "$architecture_reads" ]] || fail 'setup files must use LINUX_ARCH'

failed_skip_returns="$(find "$INSTALLER_DIR/setup" -type f -name '*.sh' \
  -exec grep -nHE '\|\| return[[:space:]]*$' {} + || true)"
[[ -z "$failed_skip_returns" ]] || fail 'skipped choices must use return 0'

if grep -RIEq 'linuxbrew|migrat(e|ion)|backwards?[ -]?compat' \
  "$INSTALLER_DIR/install.sh" "$INSTALLER_DIR/lib" "$INSTALLER_DIR/setup"; then
  fail 'installer contains an old-system migration or compatibility path'
fi
if grep -RIEq 'ubuntu|gnome|gdm|gsettings|add-apt-repository|(^|[^a-z])snap([^a-z]|$)' \
  "$INSTALLER_DIR/install.sh" "$INSTALLER_DIR/lib" "$INSTALLER_DIR/setup"; then
  fail 'installer contains a removed Linux path'
fi

for library in "$INSTALLER_DIR"/lib/*.sh "$BASH_LIB_DIR"/*.sh "$BASH_LIB_DIR"/bin/*.sh; do
  bash -n "$library"
done
[[ ! -e "$INSTALLER_DIR/mac-install.sh" ]] || fail 'old Mac installer still exists'
[[ ! -e "$INSTALLER_DIR/linux-install.sh" ]] || fail 'old Linux installer still exists'

printf 'Setup structure checks passed.\n'
