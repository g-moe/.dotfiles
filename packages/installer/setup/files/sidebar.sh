#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_file_sidebar() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_mac_sidebar() {
  local pid seconds=0

  osascript -l JavaScript "$STRATEGY_DIR/finder-sidebar.js" \
    "$HOME" "$ROOT_DIR" "$HOME/code" /Applications \
    "$HOME/Desktop" "$HOME/Documents" "$HOME/Downloads" \
    "$HOME/Pictures" "$HOME/Movies" &
  pid=$!
  while silent kill -0 "$pid"; do
    if ((seconds >= 10)); then
      silent kill "$pid" || true
      silent wait "$pid" || true
      return 1
    fi
    sleep 1
    seconds=$((seconds + 1))
  done
  wait "$pid"
}

mac() {
  local major_version
  major_version="$(sw_vers -productVersion | cut -d. -f1)"
  if ((major_version >= 26)); then
    log 'macOS 26 protects Finder sidebar files; leaving the sidebar unchanged.'
    return 0
  fi
  mkdir -p "$HOME/code"
  _mac_sidebar || log 'macOS did not allow Finder sidebar changes; continuing.'
}

linux() {
  local bookmarks directory target
  mkdir -p "$HOME/code" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
  bookmarks="file://$HOME Home
file://$ROOT_DIR .dotfiles
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
