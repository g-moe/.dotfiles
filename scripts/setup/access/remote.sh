#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

configure_remote_access() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  local state
  confirm 'Enable SSH and Screen Sharing?' || return
  sudo launchctl enable system/com.openssh.sshd
  sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist >/dev/null 2>&1 || true
  sudo launchctl print system/com.openssh.sshd >/dev/null
  open 'x-apple.systempreferences:com.apple.Sharing-Settings.extension' || true
  printf 'Turn Screen Sharing on, then press Enter: ' >/dev/tty
  read -r </dev/tty
  state="$(sudo launchctl print-disabled system 2>/dev/null || true)"
  [[ "$state" == *'"com.apple.screensharing" => enabled'* ]] ||
    die 'Screen Sharing is still off.'
  sudo launchctl print system/com.apple.screensharing >/dev/null
}

linux() {
  local password username
  confirm 'Enable SSH and GNOME Remote Desktop?' || return
  apt_install openssh-server gnome-remote-desktop
  sudo systemctl enable --now ssh
  username="$(read_value 'Remote Desktop user name' "$USER")"
  password="$(read_secret 'Remote Desktop password')"
  systemctl --user enable --now gnome-remote-desktop.service
  grdctl --headless rdp set-credentials "$username" "$password"
  grdctl --headless rdp enable
}

configure_remote_access "$1"
