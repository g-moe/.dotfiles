#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
BASH_LIB_DIR="$ROOT_DIR/packages/lib/bash"
architecture_reads=''
failed_skip_returns=''

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

while IFS= read -r strategy; do
  relative="${strategy#"$INSTALLER_DIR/setup/"}"
  registrations="$(grep -Ec "run_strategy '[^']+' $relative$" "$INSTALLER_DIR/install.sh" || true)"
  [[ "$registrations" -eq 1 ]] ||
    fail "$relative is registered $registrations times; expected once"
  grep -Fq 'case "$1" in' "$strategy" || fail "$strategy has no OS switch"
  grep -Eq '^mac\(\)[[:space:]]*\{' "$strategy" || fail "$strategy has no mac() function"
  grep -Eq '^linux\(\)[[:space:]]*\{' "$strategy" || fail "$strategy has no linux() function"
  bash -n "$strategy"
done < <(find "$INSTALLER_DIR/setup" -type f -name '*.sh' | sort)

while IFS= read -r strategy; do
  [[ -f "$INSTALLER_DIR/setup/$strategy" ]] ||
    fail "install.sh registers missing setup file: $strategy"
done < <(sed -nE "s/.*run_strategy '[^']+' ([^[:space:]]+)$/\1/p" "$INSTALLER_DIR/install.sh")

grep -Fq 'LINUX_ARCH="$(dpkg --print-architecture)"' \
  "$INSTALLER_DIR/lib/lib-install.sh" ||
  fail 'lib-install.sh does not detect the Linux CPU architecture'
architecture_reads="$(find "$INSTALLER_DIR/setup" -type f -name '*.sh' \
  -exec grep -nH 'dpkg --print-architecture' {} + || true)"
if [[ -n "$architecture_reads" ]]; then
  printf '%s\n' "$architecture_reads" >&2
  fail 'setup files must use the exported LINUX_ARCH value'
fi
failed_skip_returns="$(find "$INSTALLER_DIR/setup" -type f -name '*.sh' \
  -exec grep -nHE '\|\| return[[:space:]]*$' {} + || true)"
if [[ -n "$failed_skip_returns" ]]; then
  printf '%s\n' "$failed_skip_returns" >&2
  fail 'a skipped choice must use return 0'
fi

# Strategies are only launched by install.sh (with OS as $1). No standalone detect_os.
standalone_detect="$(find "$INSTALLER_DIR/setup" -type f -name '*.sh' \
  -exec grep -nH 'detect_os' {} + || true)"
if [[ -n "$standalone_detect" ]]; then
  printf '%s\n' "$standalone_detect" >&2
  fail 'setup files must not call detect_os; run them only via install.sh'
fi

bash -n "$INSTALLER_DIR/install.sh"
grep -Fq 'activate_repo_node "$ROOT_DIR"' "$INSTALLER_DIR/install.sh" ||
  fail 'install.sh must activate the repo Node version before running --theme'
grep -Fq 'load_homebrew ||' "$INSTALLER_DIR/install.sh" ||
  fail 'install.sh must load Homebrew commands before running --theme on macOS'
grep -Fq '"install:codium"' "$ROOT_DIR/packages/theming/create/controller.ts" ||
  fail '--theme must install its VSIX into VSCodium'
for library in "$INSTALLER_DIR"/lib/*.sh; do
  bash -n "$library"
done
for library in "$BASH_LIB_DIR"/*.sh "$BASH_LIB_DIR"/bin/*.sh; do
  bash -n "$library"
done
while IFS= read -r tool; do
  bash -n "$tool"
done < <(find "$ROOT_DIR/packages/mac" -type f -name '*.sh' | sort)

[[ ! -e "$INSTALLER_DIR/mac-install.sh" ]] || fail 'old Mac installer still exists'
[[ ! -e "$INSTALLER_DIR/linux-install.sh" ]] || fail 'old Linux installer still exists'

if grep -RIEq 'linuxbrew|migrat(e|ion)|backwards?[ -]?compat' \
  "$INSTALLER_DIR/install.sh" "$INSTALLER_DIR/lib" "$INSTALLER_DIR/setup"; then
  fail 'installer contains an old-system migration or compatibility path'
fi

# package.json machine-install scripts must invoke install.sh, not setup/*.sh directly.
root_package="$ROOT_DIR/package.json"
if [[ -f "$root_package" ]]; then
  bad_npm="$(grep -E '"install:(git|skills|machine|theme)"' "$root_package" | grep -v 'packages/installer/install\.sh' || true)"
  if [[ -n "$bad_npm" ]]; then
    printf '%s\n' "$bad_npm" >&2
    fail 'package.json install:git|skills|machine|theme must call packages/installer/install.sh'
  fi
  if grep -E '"install:[^"]+"\s*:\s*"bash packages/installer/setup/' "$root_package"; then
    fail 'package.json must not invoke packages/installer/setup/ directly'
  fi
fi

printf 'Strategy shape passed for every setup file.\n'
