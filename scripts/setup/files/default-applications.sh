#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

configure_default_applications() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  load_homebrew || die 'Homebrew is not installed.'
  duti -s com.google.Chrome http
  duti -s com.google.Chrome https
}

linux() {
  local browser

  case "$LINUX_ARCH" in
    amd64) browser='google-chrome.desktop' ;;
    arm64) browser='brave-browser.desktop' ;;
    *) die "No default browser is configured for $LINUX_ARCH" ;;
  esac

  apt_install xdg-terminal-exec
  xdg-settings set default-web-browser "$browser"
  mkdir -p "$HOME/.config"
  printf '%s\n' 'com.mitchellh.ghostty.desktop' >"$HOME/.config/xdg-terminals.list"

  [[ "$(xdg-settings get default-web-browser)" == "$browser" ]] ||
    die 'The default browser was not saved.'
  [[ "$(xdg-terminal-exec --print-id)" == 'com.mitchellh.ghostty.desktop' ]] ||
    die 'Ghostty was not saved as the default terminal.'
}

configure_default_applications "$1"
