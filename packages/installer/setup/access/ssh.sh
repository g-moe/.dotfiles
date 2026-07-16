#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_ssh() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  local choice
  choice="$(ask_choice 'SSH:' Skip Disable Enable)"
  case "$choice" in
    0) return 0 ;;
    1)
      sudo launchctl disable system/com.openssh.sshd
      silent sudo launchctl unload -w /System/Library/LaunchDaemons/ssh.plist || true
      ;;
    2)
      sudo launchctl enable system/com.openssh.sshd
      silent sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist || true
      sudo launchctl print system/com.openssh.sshd >/dev/null
      ;;
  esac
}

linux() {
  local choice
  choice="$(ask_choice 'SSH:' Skip Disable Enable)"
  case "$choice" in
    0) return 0 ;;
    1)
      if has systemctl; then
        sudo systemctl disable --now ssh 2>/dev/null ||
          sudo systemctl disable --now ssh.service 2>/dev/null ||
          true
      fi
      ;;
    2)
      apt_install openssh-server
      sudo systemctl enable --now ssh
      ;;
  esac
}

configure_ssh "$1"
