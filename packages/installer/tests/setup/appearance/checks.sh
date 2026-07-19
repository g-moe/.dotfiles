#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/test.sh"

login="$INSTALLER_DIR/setup/appearance/login-screen.sh"
for text in \
  '/etc/lightdm/lightdm-gtk-greeter.conf' \
  '/usr/local/share/backgrounds/machine-login.png' \
  'hide-user-image=false' \
  'position=50%,center 50%,center' \
  'greeter-hide-users=false' \
  'greeter-show-manual-login=false' \
  'last-user=$user' \
  'render_machine_background'; do
  expect_file_contains "$login" "$text" "login-screen setup is missing: $text"
done

icons="$INSTALLER_DIR/setup/appearance/icons.sh"
expect_file_contains "$icons" '_linux_install_tux' 'icon setup must install Tux'
expect_file_contains "$icons" 'cd503ad510e16ff2869f959cf57b892bb2175a6874ff696b495bd94fd7db9743' \
  'Tux checksum is missing'
expect_file_contains "$icons" 'xfconf_set xsettings /Net/IconThemeName string "$theme"' \
  'icon setup must use xfconf_set'

theme="$INSTALLER_DIR/setup/appearance/theme.sh"
expect_file_contains "$theme" "local theme='WhiteSur-Dark'" 'dark WhiteSur theme is missing'
expect_file_contains "$theme" 'xfce4-notifyd /theme string Rice' 'notification theme is missing'
expect_file_contains "$theme" 'extract_github_source_archive' 'theme archive must be checked'

screensaver="$INSTALLER_DIR/setup/appearance/screensaver.sh"
expect_file_contains "$screensaver" 'askForPassword -int 1' \
  'screen lock must require authentication'
expect_file_contains "$screensaver" 'askForPasswordDelay -int 0' \
  'screen lock must require authentication immediately'

wallpaper="$INSTALLER_DIR/setup/appearance/wallpaper.sh"
for text in \
  'xfconf-query -c xfce4-desktop' \
  'xrandr --listactivemonitors' \
  '/backdrop/screen0/monitor%s/workspace%s/last-image' \
  'style_property="${property%/last-image}/image-style"' \
  'xfdesktop --reload' \
  'render_machine_background'; do
  expect_file_contains "$wallpaper" "$text" "wallpaper setup is missing: $text"
done

for config in login-screen.css notifications.css; do
  [[ -f "$INSTALLER_DIR/config/xfce/$config" ]] || fail "missing Xfce config: $config"
done

printf 'Appearance setup checks passed.\n'
