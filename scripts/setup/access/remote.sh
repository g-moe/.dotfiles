#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib.sh"

configure_remote_access() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  local choice state
  choice="$(choose 'Remote access:' Skip 'Enable SSH and Screen Sharing')"
  [[ "$choice" == 1 ]] || return 0
  sudo launchctl enable system/com.openssh.sshd
  silent sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist || true
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
  local password tls_cert tls_dir tls_key username
  confirm 'Enable SSH and GNOME Remote Desktop?' || return 0
  apt_install openssh-server gnome-remote-desktop openssl
  sudo systemctl enable --now ssh
  username="$(read_value 'Remote Desktop user name' "$USER")"
  password="$(read_secret 'Remote Desktop password')"
  tls_dir="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-remote-desktop"
  tls_cert="$tls_dir/rdp-tls.crt"
  tls_key="$tls_dir/rdp-tls.key"
  mkdir -p "$tls_dir"
  if [[ ! -s "$tls_cert" || ! -s "$tls_key" ]]; then
    silent openssl req -new -newkey rsa:4096 -days 720 -nodes -x509 \
      -subj "/CN=$(hostname)" \
      -keyout "$tls_key" \
      -out "$tls_cert"
    chmod 600 "$tls_key"
  fi
  grdctl --headless rdp set-tls-cert "$tls_cert"
  grdctl --headless rdp set-tls-key "$tls_key"
  grdctl --headless rdp set-credentials "$username" "$password"
  grdctl --headless rdp enable
  systemctl --user enable --now gnome-remote-desktop-headless.service
  systemctl --user is-active --quiet gnome-remote-desktop-headless.service ||
    die 'GNOME Remote Desktop did not start.'
}

configure_remote_access "$1"
