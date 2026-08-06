#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/test.sh"

desktop="$INSTALLER_DIR/setup/system/desktop-environment.sh"
spotlight="$INSTALLER_DIR/setup/system/spotlight.sh"
if grep -Fq 'apt_install' "$desktop"; then
  fail 'desktop-environment check must not install a desktop'
fi

expect_file_contains "$INSTALLER_DIR/lib/lib-install.sh" '"$ID" == debian' \
  'installer must require Debian'
expect_file_contains "$INSTALLER_DIR/lib/lib-install.sh" '"$VERSION_ID" == 13' \
  'installer must require Debian 13'
expect_file_contains "$INSTALLER_DIR/lib/lib-install.sh" '"$VERSION_CODENAME" == trixie' \
  'installer must require trixie'

system_phase="$(sed -n '/^configure_system() {/,/^}/p' "$INSTALLER_DIR/install.sh")"
grep -Fq 'system/display.sh' <<<"$system_phase" ||
  fail 'display setup must stay in the system phase'
check_phase="$(sed -n '/^check_linux_desktop() {/,/^}/p' "$INSTALLER_DIR/install.sh")"
if grep -Fq 'display.sh' <<<"$check_phase"; then
  fail 'the read-only desktop check must not configure the display'
fi
grep -Fq 'system/spotlight.sh' <<<"$system_phase" ||
  fail 'Spotlight setup must stay in the system phase'
expect_file_contains "$spotlight" 'sudo mdutil -a -i off' \
  'Spotlight setup must disable indexing on all mounted volumes'
expect_file_contains "$spotlight" 'mdutil -a -s' \
  'Spotlight setup must report indexing status after the change'
if grep -Eq 'mdutil .*-[^ ]*E' "$spotlight"; then
  fail 'Spotlight setup must not erase and rebuild the index'
fi

printf 'System setup checks passed.\n'
