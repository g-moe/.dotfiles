#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$APP_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib.sh"

install_codex() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  brew_cask codex-app
}

linux() {
  local archive asset_arch binary temporary_dir

  case "$LINUX_ARCH" in
    amd64) asset_arch=x86_64 ;;
    arm64) asset_arch=aarch64 ;;
    *) die "Codex has no Linux build for $LINUX_ARCH" ;;
  esac
  archive="$(download_github_asset openai/codex \
    "^codex-${asset_arch}-unknown-linux-musl\\.tar\\.gz$" .tar.gz)"
  temporary_dir="$(mktemp -d)"
  tar -xzf "$archive" -C "$temporary_dir"
  binary="$(find "$temporary_dir" -type f \
    -name "codex-${asset_arch}-unknown-linux-musl" | head -n 1)"
  [[ -n "$binary" ]] || die 'The Codex archive did not contain Codex.'
  sudo install -m 0755 "$binary" /usr/local/bin/codex
  rm -rf "$temporary_dir" "$archive"
}

install_codex "$1"
