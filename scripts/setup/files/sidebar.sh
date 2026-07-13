#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

configure_file_sidebar() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  local script="$STRATEGY_DIR/finder-sidebar.js"
  mkdir -p "$HOME/code"
  if ! osascript -l JavaScript "$script" \
    "$HOME" "$ROOT_DIR" "$HOME/code" /Applications \
    "$HOME/Desktop" "$HOME/Documents" "$HOME/Downloads" \
    "$HOME/Pictures" "$HOME/Movies"; then
    open 'x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles' || true
    printf 'Give this terminal Full Disk Access, then press Enter: ' >/dev/tty
    read -r </dev/tty
    osascript -l JavaScript "$script" \
      "$HOME" "$ROOT_DIR" "$HOME/code" /Applications \
      "$HOME/Desktop" "$HOME/Documents" "$HOME/Downloads" \
      "$HOME/Pictures" "$HOME/Movies"
  fi
}

linux() {
  local bookmarks directory target
  mkdir -p "$HOME/code" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
  bookmarks="file://$HOME Home
file://$ROOT_DIR .config
file://$HOME/code code
file://$HOME/Desktop Desktop
file://$HOME/Documents Documents
file://$HOME/Downloads Downloads
file://$HOME/Pictures Pictures
file://$HOME/Videos Videos"
  for directory in gtk-3.0 gtk-4.0; do
    target="$HOME/.config/$directory/bookmarks"
    printf '%s\n' "$bookmarks" >"$target"
  done
}

configure_file_sidebar "$1"
