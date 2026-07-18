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

_linux_install_tux() {
  local png_file svg_file temporary_dir
  local png_checksum='d00669311ce154e8a990e61cb1cd34ddcb32813a5dde49647b8dc1e605385d35'
  local svg_checksum='cd503ad510e16ff2869f959cf57b892bb2175a6874ff696b495bd94fd7db9743'
  local png_path='/usr/local/share/icons/tux.png'
  local svg_path='/usr/local/share/icons/tux.svg'

  if [[ -f "$svg_path" && -f "$png_path" ]] &&
    printf '%s  %s\n%s  %s\n' \
      "$svg_checksum" "$svg_path" \
      "$png_checksum" "$png_path" |
      sha256sum --check --status; then
    return 0
  fi

  temporary_dir="$(mktemp -d)"
  svg_file="$temporary_dir/tux.svg"
  png_file="$temporary_dir/tux.png"
  # Canonical Tux artwork and credits:
  # https://commons.wikimedia.org/wiki/File:Tux.svg
  curl -fsSL \
    'https://upload.wikimedia.org/wikipedia/commons/archive/3/35/20260328100427%21Tux.svg' \
    -o "$svg_file"
  curl -fsSL \
    'https://upload.wikimedia.org/wikipedia/commons/thumb/archive/3/35/20260328100427%21Tux.svg/250px-Tux.svg.png' \
    -o "$png_file"
  printf '%s  %s\n%s  %s\n' \
    "$svg_checksum" "$svg_file" \
    "$png_checksum" "$png_file" |
    sha256sum --check --status || die 'Tux icon checksum failed.'
  sudo install -D -m 0644 "$svg_file" "$svg_path"
  sudo install -D -m 0644 "$png_file" "$png_path"
  rm -rf "$temporary_dir"
}

linux() {
  local source_dir temporary_dir
  local theme='WhiteSur'
  local commit='be13578d05bc1ada81a0243516340d8892ebaccc'
  local checksum='731cffec0e4960e85c0524e9bc5045bb4068da285ca05ce263dff4343a393959'

  apt_install curl
  _linux_install_tux
  ask_binary 'Use WhiteSur icons?' || return 0
  apt_install libgtk-3-bin xfconf

  temporary_dir="$(mktemp -d)"
  source_dir="$(
    extract_github_source_archive \
      vinceliuice/WhiteSur-icon-theme "$commit" "$checksum" "$temporary_dir"
  )"

  bash "$source_dir/install.sh" -d "$HOME/.local/share/icons" -t default
  rm -rf "$temporary_dir"

  [[ -d "$HOME/.local/share/icons/$theme" ]] ||
    die "WhiteSur icon theme is missing: $theme"
  xfconf_set xsettings /Net/IconThemeName string "$theme"
  [[ "$(xfconf-query -c xsettings -p /Net/IconThemeName)" == "$theme" ]] ||
    die 'The WhiteSur icon theme was not saved.'
}

configure_icons "$1"
