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

# Boot-level system service (root) so VNC can attach to :0 at the greeter,
# before a user session exists. Display server (X11) is system/display-server.sh.
linux_install_vnc_service() {
  install_root_file /etc/systemd/system/x11vnc.service \
    '[Unit]
Description=x11vnc shared desktop on :0
After=display-manager.service
Wants=display-manager.service
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=/usr/bin/x11vnc -display :0 -auth guess -forever -shared -rfbauth /etc/x11vnc.passwd -rfbport 5900 -localhost -noxdamage -repeat
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target'
  sudo systemctl daemon-reload
  sudo systemctl enable x11vnc.service
}

linux_store_vnc_password() {
  local password="$1"
  local temporary_file

  temporary_file="$(mktemp)"
  x11vnc -storepasswd "$password" "$temporary_file"
  sudo install -D -m 0600 "$temporary_file" /etc/x11vnc.passwd
  rm -f "$temporary_file"
}

linux_vnc_service_is_ready() {
  systemctl is-active --quiet x11vnc.service &&
    ss -ltn | grep -qE '[:.]5900[[:space:]]'
}

linux() {
  local choice password
  choice="$(ask_choice 'VNC:' Skip Disable Enable)"
  case "$choice" in
    0) return 0 ;;
    1)
      silent sudo systemctl disable --now x11vnc.service || true
      silent sudo systemctl reset-failed x11vnc.service || true
      ;;
    2)
      apt_install iproute2 x11vnc
      password="$(read_secret 'VNC password')"
      # Classic VNC passwords are capped at 8 characters.
      [[ -n "$password" ]] || die 'VNC password cannot be empty.'
      [[ "${#password}" -le 8 ]] || die 'VNC password must be 8 characters or fewer.'
      linux_store_vnc_password "$password"
      linux_install_vnc_service
      silent sudo systemctl restart x11vnc.service || true
      if [[ -S /tmp/.X11-unix/X0 ]]; then
        retry 10 1 linux_vnc_service_is_ready ||
          die 'x11vnc did not start on display :0.'
      else
        # Display manager has not created :0 yet (common during SSH installs).
        log 'VNC service enabled; it will attach when display :0 is up.'
      fi
      ;;
  esac
}

configure_vnc "$1"
