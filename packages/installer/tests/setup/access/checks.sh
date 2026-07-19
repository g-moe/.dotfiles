#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/test.sh"

vnc="$INSTALLER_DIR/setup/access/vnc.sh"
for text in \
  '/etc/systemd/system/x11vnc.service' \
  '-display :0' \
  '/etc/x11vnc.passwd' \
  '-localhost' \
  'retry 10 1 linux_vnc_service_is_ready'; do
  expect_file_contains "$vnc" "$text" "VNC is missing: $text"
done
if grep -Fq 'systemctl --user' "$vnc"; then
  fail 'VNC must not use a user service'
fi

printf 'Access setup checks passed.\n'
