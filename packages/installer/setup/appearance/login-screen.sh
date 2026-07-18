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
  local account_file avatar background color color_hex config css_file greeter_state
  local icon_name icon_source icon_theme='Adwaita' output_size='3840x2160'
  local temporary_dir user user_path

  apt_install accountsservice fonts-jetbrains-mono imagemagick lightdm-gtk-greeter
  has busctl || die 'AccountsService control is missing.'
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

  for icon_source in "$HOME/.local/share/icons"/WhiteSur*; do
    [[ -d "$icon_source" ]] || continue
    icon_name="$(basename "$icon_source")"
    sudo rm -rf "/usr/local/share/icons/$icon_name"
    sudo install -d -m 0755 /usr/local/share/icons
    sudo cp -a --no-preserve=ownership "$icon_source" /usr/local/share/icons/
    [[ "$icon_name" == WhiteSur-dark ]] && icon_theme='WhiteSur-dark'
  done

  [[ -s /usr/local/share/icons/tux.png ]] ||
    die 'The Tux avatar is missing. Run the appearance phase again.'
  user="$(id -un)"
  avatar="/var/lib/AccountsService/icons/$user.png"
  account_file="/var/lib/AccountsService/users/$user"
  user_path="/org/freedesktop/Accounts/User$(id -u)"
  sudo install -D -m 0644 /usr/local/share/icons/tux.png "$avatar"
  silent sudo busctl call org.freedesktop.Accounts "$user_path" \
    org.freedesktop.Accounts.User SetIconFile s "$avatar"

  css_file="$temporary_dir/login-screen.css"
  sed "s/@RICE_ACCENT@/$color_hex/g" \
    "$INSTALLER_DIR/config/xfce/login-screen.css" >"$css_file"
  sudo install -D -o lightdm -g lightdm -m 0644 "$css_file" \
    /var/lib/lightdm/.config/gtk-3.0/gtk.css

  config="[greeter]
background=$background
user-background=false
theme-name=Adwaita-dark
icon-theme-name=$icon_theme
cursor-theme-name=Adwaita
cursor-theme-size=24
font-name=JetBrains Mono 11
xft-antialias=true
xft-dpi=96
xft-hintstyle=slight
xft-rgba=rgb
position=50%,center 50%,center
hide-user-image=false
panel-position=top
clock-format=%b %d  %H:%M
indicators=~spacer;~clock;~power
transition-duration=0
transition-type=none
screensaver-timeout=0"
  install_root_file /etc/lightdm/lightdm-gtk-greeter.conf "$config"
  install_root_file /etc/lightdm/lightdm.conf.d/90-rice-greeter.conf \
    $'[Seat:*]\ngreeter-hide-users=false\ngreeter-show-manual-login=false\ngreeter-allow-guest=false'

  greeter_state="[greeter]
last-user=$user
last-session=lightdm-xsession"
  sudo install -d -o lightdm -g lightdm -m 0755 \
    /var/lib/lightdm/.cache/lightdm-gtk-greeter
  install_root_file /var/lib/lightdm/.cache/lightdm-gtk-greeter/state "$greeter_state"
  sudo chown lightdm:lightdm /var/lib/lightdm/.cache/lightdm-gtk-greeter/state
  rm -rf "$temporary_dir"

  [[ -s "$background" ]] || die 'Login screen background is missing.'
  grep -Fqx "background=$background" /etc/lightdm/lightdm-gtk-greeter.conf ||
    die 'The LightDM login background was not saved.'
  grep -Fqx 'position=50%,center 50%,center' /etc/lightdm/lightdm-gtk-greeter.conf ||
    die 'The LightDM login was not centered.'
  sudo grep -Fqx "Icon=$avatar" "$account_file" ||
    die 'The LightDM Tux avatar was not saved.'
  sudo grep -Fqx "last-user=$user" \
    /var/lib/lightdm/.cache/lightdm-gtk-greeter/state ||
    die 'The LightDM login user was not saved.'
  log 'LightDM login styling will appear after reboot or sign out.'
}

configure_login_screen "$1"
