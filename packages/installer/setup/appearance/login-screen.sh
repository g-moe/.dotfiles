#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_login_screen() {
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
  local background color color_hex config icon_theme='Adwaita'
  local output_size='3840x2160' temporary_dir theme='Adwaita'
  local icon_source="$HOME/.local/share/icons/WhiteSur"
  local theme_source="$HOME/.themes/WhiteSur-Light"

  apt_install fonts-jetbrains-mono imagemagick lightdm-gtk-greeter
  [[ "$(cat /etc/X11/default-display-manager 2>/dev/null || true)" == /usr/sbin/lightdm ]] ||
    die 'LightDM must be the default display manager.'

  temporary_dir="$(mktemp -d)"
  color="$(machine_field "$ROOT_DIR/machine.json" color)"
  color_hex="$(machine_color_hex "$color")"
  magick "$ROOT_DIR/images/white.png" \
    -rotate 180 \
    -colorspace gray \
    +level-colors '#000000',"$color_hex" \
    -resize "$output_size!" \
    "$temporary_dir/base.png" || die 'Could not color the login background.'
  magick "$temporary_dir/base.png" \
    \( -size 1504x847 radial-gradient:white-black +level '25%,100%' -resize "$output_size!" \) \
    -compose multiply \
    -composite \
    "$temporary_dir/login.png" || die 'Could not create the login background.'

  background='/usr/local/share/backgrounds/machine-login.png'
  sudo install -D -m 0644 "$temporary_dir/login.png" "$background"

  if [[ -d "$theme_source" ]]; then
    sudo rm -rf /usr/local/share/themes/WhiteSur-Light
    sudo install -d -m 0755 /usr/local/share/themes
    sudo cp -a --no-preserve=ownership "$theme_source" /usr/local/share/themes/
    theme='WhiteSur-Light'
  fi
  if [[ -d "$icon_source" ]]; then
    sudo rm -rf /usr/local/share/icons/WhiteSur
    sudo install -d -m 0755 /usr/local/share/icons
    sudo cp -a --no-preserve=ownership "$icon_source" /usr/local/share/icons/
    icon_theme='WhiteSur'
  fi

  config="[greeter]
background=$background
user-background=false
theme-name=$theme
icon-theme-name=$icon_theme
cursor-theme-name=Adwaita
cursor-theme-size=24
font-name=JetBrains Mono 11
xft-antialias=true
xft-dpi=96
xft-hintstyle=slight
xft-rgba=rgb
position=50% 50%
hide-user-image=true
panel-position=top
clock-format=%a %b %d  %H:%M
indicators=~host;~spacer;~layout;~session;~clock;~power
transition-duration=0
transition-type=none
screensaver-timeout=0"
  install_root_file /etc/lightdm/lightdm-gtk-greeter.conf "$config"
  rm -rf "$temporary_dir"

  [[ -s "$background" ]] || die 'Login screen background is missing.'
  grep -Fqx "background=$background" /etc/lightdm/lightdm-gtk-greeter.conf ||
    die 'The LightDM login background was not saved.'
  log 'LightDM login styling will appear after reboot or sign out.'
}

configure_login_screen "$1"
