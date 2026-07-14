#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

configure_icons() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  return 0
}

linux() {
  local archive source_dir temporary_dir
  local version='2026-07-07'
  local checksum='e55e2ef2d938185dd770a6a91e7f104166146abb474047c26d238cd652f030e3'
  local theme='MacTahoe-blue-dark'

  has gtk-update-icon-cache || die 'Ubuntu icon tools are missing.'
  archive="$(mktemp --suffix=.tar.gz)"
  temporary_dir="$(mktemp -d)"
  curl -fL \
    "https://codeload.github.com/vinceliuice/MacTahoe-icon-theme/tar.gz/refs/tags/$version" \
    -o "$archive"
  printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check --status ||
    die 'MacTahoe icon theme checksum failed.'
  tar -xzf "$archive" -C "$temporary_dir"
  source_dir="$temporary_dir/MacTahoe-icon-theme-$version"
  bash "$source_dir/install.sh" -d "$HOME/.local/share/icons" -t blue
  rm -f "$archive"
  rm -rf "$temporary_dir"

  gsettings set org.gnome.desktop.interface icon-theme "$theme"
  [[ "$(gsettings get org.gnome.desktop.interface icon-theme)" == "'$theme'" ]] ||
    die 'The MacTahoe icon theme was not saved.'
}

configure_icons "$1"
