#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_theme() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  local color tint
  ask_binary 'Set the dark theme and machine color?' || return 0
  color="$(machine_field "$ROOT_DIR/machine.json" color)"
  tint="$(machine_color_tint "$color")"
  defaults write NSGlobalDomain AppleAccentColor -int 4
  defaults write NSGlobalDomain AppleHighlightColor -string '0.698039 0.843137 1.000000 Blue'
  defaults write NSGlobalDomain AppleInterfaceStyle -string Dark
  defaults write NSGlobalDomain NSGlassDiffusionSetting -int 0
  defaults write NSGlobalDomain AppleReduceDesktopTinting -bool true
  defaults write NSGlobalDomain AppleIconAppearanceTheme -string ClearLight
  defaults write NSGlobalDomain AppleIconAppearanceTintColor -string Other
  defaults write NSGlobalDomain AppleIconAppearanceCustomTintColor -string "$tint"
}

linux() {
  local archive source_dir temporary_dir
  local theme='WhiteSur-Light'
  local commit='cd814d4286cbe4638390baacf4db5e66f4506f1a'
  local checksum='a26476c42bb4b9d0c590e5533a59bbc3555bd3290627292e0a0e7fe9db3c9078'

  ask_binary 'Use WhiteSur desktop styling?' || return 0
  apt_install xfconf xz-utils

  archive="$(mktemp --suffix=.tar.gz)"
  temporary_dir="$(mktemp -d)"
  curl -fsSL \
    "https://codeload.github.com/vinceliuice/WhiteSur-gtk-theme/tar.gz/$commit" \
    -o "$archive"
  printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check --status ||
    die 'WhiteSur window theme checksum failed.'
  tar -xzf "$archive" -C "$temporary_dir"
  source_dir="$temporary_dir/WhiteSur-gtk-theme-$commit"

  mkdir -p "$HOME/.themes"
  rm -rf "$HOME/.themes/$theme"
  tar -xJf "$source_dir/release/$theme.tar.xz" -C "$HOME/.themes"
  rm -f "$archive"
  rm -rf "$temporary_dir"

  [[ -d "$HOME/.themes/$theme/xfwm4" ]] ||
    die "WhiteSur desktop theme is missing: $theme"
  xfconf-query -c xsettings -p /Net/ThemeName -s "$theme"
  xfconf-query -c xfwm4 -p /general/theme -s "$theme"
  [[ "$(xfconf-query -c xsettings -p /Net/ThemeName)" == "$theme" ]] ||
    die 'The WhiteSur GTK theme was not saved.'
  [[ "$(xfconf-query -c xfwm4 -p /general/theme)" == "$theme" ]] ||
    die 'The WhiteSur window theme was not saved.'
}

configure_theme "$1"
