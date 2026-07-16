#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

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
  local theme='WhiteSur'
  local commit='be13578d05bc1ada81a0243516340d8892ebaccc'
  local checksum='731cffec0e4960e85c0524e9bc5045bb4068da285ca05ce263dff4343a393959'

  ask_binary 'Use WhiteSur icons?' || return 0
  apt_install libgtk-3-bin xfconf

  archive="$(mktemp --suffix=.tar.gz)"
  temporary_dir="$(mktemp -d)"
  curl -fsSL \
    "https://codeload.github.com/vinceliuice/WhiteSur-icon-theme/tar.gz/$commit" \
    -o "$archive"
  printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check --status ||
    die 'WhiteSur icon theme checksum failed.'
  tar -xzf "$archive" -C "$temporary_dir"
  source_dir="$temporary_dir/WhiteSur-icon-theme-$commit"

  bash "$source_dir/install.sh" -d "$HOME/.local/share/icons" -t default
  rm -f "$archive"
  rm -rf "$temporary_dir"

  [[ -d "$HOME/.local/share/icons/$theme" ]] ||
    die "WhiteSur icon theme is missing: $theme"
  xfconf-query -c xsettings -p /Net/IconThemeName -s "$theme"
  [[ "$(xfconf-query -c xsettings -p /Net/IconThemeName)" == "$theme" ]] ||
    die 'The WhiteSur icon theme was not saved.'
}

configure_icons "$1"
