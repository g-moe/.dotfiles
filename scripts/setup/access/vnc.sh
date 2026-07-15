#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib.sh"

configure_vnc() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  local choice state
  choice="$(ask_choice 'VNC:' Skip Enable Disable)"
  case "$choice" in
    0) return 0 ;;
    1)
      open 'x-apple.systempreferences:com.apple.Sharing-Settings.extension' || true
      printf 'Turn Screen Sharing on, then press Enter: ' >/dev/tty
      read -r </dev/tty
      state="$(sudo launchctl print-disabled system 2>/dev/null || true)"
      [[ "$state" == *'"com.apple.screensharing" => enabled'* ]] ||
        die 'Screen Sharing is still off.'
      sudo launchctl print system/com.apple.screensharing >/dev/null
      ;;
    2)
      open 'x-apple.systempreferences:com.apple.Sharing-Settings.extension' || true
      printf 'Turn Screen Sharing off, then press Enter: ' >/dev/tty
      read -r </dev/tty
      state="$(sudo launchctl print-disabled system 2>/dev/null || true)"
      [[ "$state" == *'"com.apple.screensharing" => disabled'* ]] ||
        die 'Screen Sharing is still on.'
      ;;
  esac
}

linux() {
  local choice password tls_cert tls_dir tls_key username
  choice="$(ask_choice 'VNC:' Skip Enable Disable)"
  case "$choice" in
    0) return 0 ;;
    1)
      apt_install gnome-remote-desktop openssl
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
      ;;
    2)
      if has grdctl; then
        silent grdctl --headless rdp disable || true
      fi
      silent systemctl --user disable --now gnome-remote-desktop-headless.service || true
      ;;
  esac
}

configure_vnc "$1"
