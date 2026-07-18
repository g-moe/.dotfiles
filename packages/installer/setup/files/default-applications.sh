#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_default_applications() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  local attempt

  load_homebrew || die 'Homebrew is not installed.'
  if [[ "$(duti -d http 2>/dev/null || true)" == 'com.google.Chrome' &&
    "$(duti -d https 2>/dev/null || true)" == 'com.google.Chrome' ]]; then
    return 0
  fi

  # macOS asks the signed-in user to approve a default-browser change. Setting
  # the HTTP handler opens that one system prompt and approval covers HTTPS too.
  silent duti -s com.google.Chrome http || true
  log 'Approve Chrome in the macOS default-browser prompt.'
  for attempt in {1..120}; do
    if [[ "$(duti -d http 2>/dev/null || true)" == 'com.google.Chrome' &&
      "$(duti -d https 2>/dev/null || true)" == 'com.google.Chrome' ]]; then
      return 0
    fi
    sleep 1
  done

  die 'Chrome was not approved as the default browser.'
}

linux() {
  local browser

  case "$LINUX_ARCH" in
    amd64) browser='google-chrome.desktop' ;;
    arm64) browser='brave-browser.desktop' ;;
    *) die "No default browser is configured for $LINUX_ARCH" ;;
  esac

  xdg-settings set default-web-browser "$browser"

  [[ "$(xdg-settings get default-web-browser)" == "$browser" ]] ||
    die 'The default browser was not saved.'
}

configure_default_applications "$1"
