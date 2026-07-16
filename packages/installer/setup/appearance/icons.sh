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
  local archive temporary_dir
  local theme='GreyStone'
  local commit='872ef715eeacebfdf57c38866195c52d118e9ced'
  local checksum='931849f0ca1fa698bbdbfda7859cfb3397b39d45242f18287218b441c5c0573d'

  has gtk-update-icon-cache || die 'Ubuntu icon tools are missing.'
  # GreyStone inherits Papirus-Dark for uncovered apps.
  apt_install papirus-icon-theme
  [[ -d /usr/share/icons/Papirus-Dark ]] ||
    die 'Papirus-Dark is required by GreyStone but was not found.'

  archive="$(mktemp --suffix=.tar.gz)"
  temporary_dir="$(mktemp -d)"
  curl -fL \
    "https://codeberg.org/StormRosenaa/GreyStone/raw/commit/$commit/GreyStone.tar.gz" \
    -o "$archive"
  printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check --status ||
    die 'GreyStone icon theme checksum failed.'
  tar -xzf "$archive" -C "$temporary_dir"
  mkdir -p "$HOME/.local/share/icons"
  rm -rf "$HOME/.local/share/icons/$theme"
  cp -a "$temporary_dir/$theme" "$HOME/.local/share/icons/$theme"
  silent gtk-update-icon-cache -f "$HOME/.local/share/icons/$theme" || true
  rm -f "$archive"
  rm -rf "$temporary_dir"

  [[ -d "$HOME/.local/share/icons/$theme" ]] ||
    die "GreyStone theme missing after install: $theme"
  gsettings set org.gnome.desktop.interface icon-theme "$theme"
  [[ "$(gsettings get org.gnome.desktop.interface icon-theme)" == "'$theme'" ]] ||
    die 'The GreyStone icon theme was not saved.'
}

configure_icons "$1"
