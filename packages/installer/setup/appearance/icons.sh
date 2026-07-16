#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
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
  local accent archive color source_dir temporary_dir theme
  local version='v2.6'
  local checksum='8a25304dd641cdf3f096ec94d6b47dd7184aac8efb64a9995629cf3165dc8790'

  has gtk-update-icon-cache || die 'Ubuntu icon tools are missing.'
  apt_install adwaita-icon-theme

  color="$(machine_field "$ROOT_DIR/machine.json" color)"
  case "$color" in
    aqua) accent=teal ;;
    gray) accent=slate ;;
    *) accent="$color" ;;
  esac
  theme="Adwaita-$accent"

  archive="$(mktemp --suffix=.tar.gz)"
  temporary_dir="$(mktemp -d)"
  curl -fL \
    "https://codeload.github.com/dpejoh/Adwaita-Colors/tar.gz/refs/tags/$version" \
    -o "$archive"
  printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check --status ||
    die 'Adwaita Colors checksum failed.'
  tar -xzf "$archive" -C "$temporary_dir"
  source_dir="$temporary_dir/Adwaita-Colors-2.6"
  bash "$source_dir/setup" -i "$accent"
  rm -f "$archive"
  rm -rf "$temporary_dir"

  [[ -d "$HOME/.local/share/icons/$theme" ]] ||
    die "Adwaita Colors theme missing after install: $theme"
  gsettings set org.gnome.desktop.interface icon-theme "$theme"
  [[ "$(gsettings get org.gnome.desktop.interface icon-theme)" == "'$theme'" ]] ||
    die 'The Adwaita Colors icon theme was not saved.'
}

configure_icons "$1"
