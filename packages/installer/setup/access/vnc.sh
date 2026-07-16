#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_vnc() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  local choice state
  choice="$(ask_choice 'VNC:' Skip Disable Enable)"
  case "$choice" in
    0) return 0 ;;
    1)
      open 'x-apple.systempreferences:com.apple.Sharing-Settings.extension' || true
      printf 'Turn Screen Sharing off, then press Enter: ' >/dev/tty
      read -r </dev/tty
      state="$(sudo launchctl print-disabled system 2>/dev/null || true)"
      [[ "$state" == *'"com.apple.screensharing" => disabled'* ]] ||
        die 'Screen Sharing is still on.'
      ;;
    2)
      open 'x-apple.systempreferences:com.apple.Sharing-Settings.extension' || true
      printf 'Turn Screen Sharing on, then press Enter: ' >/dev/tty
      read -r </dev/tty
      state="$(sudo launchctl print-disabled system 2>/dev/null || true)"
      [[ "$state" == *'"com.apple.screensharing" => enabled'* ]] ||
        die 'Screen Sharing is still off.'
      sudo launchctl print system/com.apple.screensharing >/dev/null
      ;;
  esac
}

linux() {
  local choice password
  choice="$(ask_choice 'VNC:' Skip Disable Enable)"
  case "$choice" in
    0) return 0 ;;
    1)
      if has grdctl; then
        silent grdctl --headless vnc disable || true
        silent grdctl --headless rdp disable || true
      fi
      silent systemctl --user disable --now gnome-remote-desktop-headless.service || true
      ;;
    2)
      apt_install gnome-remote-desktop
      password="$(read_secret 'VNC password')"
      grdctl --headless vnc set-password "$password"
      grdctl --headless vnc enable
      silent grdctl --headless rdp disable || true
      systemctl --user enable --now gnome-remote-desktop-headless.service
      systemctl --user is-active --quiet gnome-remote-desktop-headless.service ||
        die 'GNOME Remote Desktop did not start.'
      ;;
  esac
}

configure_vnc "$1"
