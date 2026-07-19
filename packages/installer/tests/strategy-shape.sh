#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
BASH_LIB_DIR="$ROOT_DIR/packages/lib/bash"
architecture_reads=''
failed_skip_returns=''
log_only_skips=''

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

while IFS= read -r strategy; do
  relative="${strategy#"$INSTALLER_DIR/setup/"}"
  registrations="$(grep -Ec "run_strategy '[^']+' $relative$" "$INSTALLER_DIR/install.sh" || true)"
  [[ "$registrations" -eq 1 ]] ||
    fail "$relative is registered $registrations times; expected once"
  grep -Fq 'case "$1" in' "$strategy" || fail "$strategy has no OS switch"
  grep -Eq '^mac\(\)[[:space:]]*\{' "$strategy" || fail "$strategy has no mac() function"
  grep -Eq '^linux\(\)[[:space:]]*\{' "$strategy" || fail "$strategy has no linux() function"
  bash -n "$strategy"
done < <(find "$INSTALLER_DIR/setup" -type f -name '*.sh' | sort)

while IFS= read -r strategy; do
  [[ -f "$INSTALLER_DIR/setup/$strategy" ]] ||
    fail "install.sh registers missing setup file: $strategy"
done < <(sed -nE "s/.*run_strategy '[^']+' ([^[:space:]]+)$/\1/p" "$INSTALLER_DIR/install.sh")

grep -Fq 'LINUX_ARCH="$(dpkg --print-architecture)"' \
  "$INSTALLER_DIR/lib/lib-install.sh" ||
  fail 'lib-install.sh does not detect the Linux CPU architecture'
grep -Fq '"$ID" == debian' "$INSTALLER_DIR/lib/lib-install.sh" ||
  fail 'lib-install.sh does not require Debian'
grep -Fq '"$VERSION_ID" == 13' "$INSTALLER_DIR/lib/lib-install.sh" ||
  fail 'lib-install.sh does not require Debian 13'
grep -Fq '"$VERSION_CODENAME" == trixie' "$INSTALLER_DIR/lib/lib-install.sh" ||
  fail 'lib-install.sh does not require trixie'
architecture_reads="$(find "$INSTALLER_DIR/setup" -type f -name '*.sh' \
  -exec grep -nH 'dpkg --print-architecture' {} + || true)"
if [[ -n "$architecture_reads" ]]; then
  printf '%s\n' "$architecture_reads" >&2
  fail 'setup files must use the exported LINUX_ARCH value'
fi
failed_skip_returns="$(find "$INSTALLER_DIR/setup" -type f -name '*.sh' \
  -exec grep -nHE '\|\| return[[:space:]]*$' {} + || true)"
if [[ -n "$failed_skip_returns" ]]; then
  printf '%s\n' "$failed_skip_returns" >&2
  fail 'a skipped choice must use return 0'
fi
log_only_skips="$(
  awk '
    /^(mac|linux)\(\) \{$/ {
      in_platform = 1
      start = FNR
      has_log = 0
      has_return = 0
      only_skip_lines = 1
      next
    }
    in_platform && /^}$/ {
      if (has_log && only_skip_lines && !has_return) {
        print FILENAME ":" start
      }
      in_platform = 0
      next
    }
    in_platform {
      if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^[[:space:]]*#/) next
      if ($0 ~ /^[[:space:]]*log /) {
        has_log = 1
        next
      }
      if ($0 ~ /^[[:space:]]*return 0[[:space:]]*$/) {
        has_return = 1
        next
      }
      only_skip_lines = 0
    }
  ' $(find "$INSTALLER_DIR/setup" -type f -name '*.sh' | sort)
)"
if [[ -n "$log_only_skips" ]]; then
  printf '%s\n' "$log_only_skips" >&2
  fail 'a log-only platform skip must end with return 0'
fi

# Strategies are only launched by install.sh (with OS as $1). No standalone detect_os.
standalone_detect="$(find "$INSTALLER_DIR/setup" -type f -name '*.sh' \
  -exec grep -nH 'detect_os' {} + || true)"
if [[ -n "$standalone_detect" ]]; then
  printf '%s\n' "$standalone_detect" >&2
  fail 'setup files must not call detect_os; run them only via install.sh'
fi

bash -n "$INSTALLER_DIR/install.sh"
grep -Fq 'activate_repo_node "$ROOT_DIR"' "$INSTALLER_DIR/install.sh" ||
  fail 'install.sh must activate the repo Node version before running --theme'
grep -Fq 'load_homebrew ||' "$INSTALLER_DIR/install.sh" ||
  fail 'install.sh must load Homebrew commands before running --theme on macOS'
grep -Fq "log 'A reboot is recommended.'" "$INSTALLER_DIR/install.sh" ||
  fail 'install.sh must recommend a reboot when setup finishes'
grep -Fq "ask_binary 'Reboot now?' n" "$INSTALLER_DIR/install.sh" ||
  fail 'install.sh must ask before rebooting and default to no'
grep -Fq "ask_binary 'Install NordVPN?' n" "$INSTALLER_DIR/setup/apps/nordvpn.sh" ||
  fail 'NordVPN prompt must default to no'
grep -Fq 'brew_cask google-chrome arc' "$INSTALLER_DIR/setup/apps/chrome.sh" ||
  fail 'Mac must install both Chrome and Arc'
grep -Fq 'brew_formula mactop' "$INSTALLER_DIR/setup/apps/system-monitor.sh" ||
  fail 'Mac must install mactop as the system monitor'
grep -Fq 'safe_symlink_group mactop' "$INSTALLER_DIR/setup/apps/system-monitor.sh" ||
  fail 'mactop configuration and login agent must be linked'
grep -Fq 'launchctl bootstrap "$domain" "$agent_path"' "$INSTALLER_DIR/setup/apps/system-monitor.sh" ||
  fail 'mactop menu bar must start at login'
grep -Fq '<string>/usr/bin/script</string>' "$ROOT_DIR/mactop/com.dotfiles.mactop-menubar.plist" ||
  fail 'mactop login startup must provide the tty required by menubar mode'
grep -Fq 'sudo shutdown -r now' "$INSTALLER_DIR/install.sh" ||
  fail 'install.sh must use the shared macOS and Linux reboot command'
grep -Fq '"install:codium"' "$ROOT_DIR/packages/theming/create/controller.ts" ||
  fail '--theme must install its VSIX into VSCodium'
grep -Fq 'mkdir -p "$HOME/.nvm"' \
  "$INSTALLER_DIR/setup/development/node.sh" ||
  fail 'Node setup must create its fixed NVM directory before installing NVM'
for library in "$INSTALLER_DIR"/lib/*.sh; do
  bash -n "$library"
done
for library in "$BASH_LIB_DIR"/*.sh "$BASH_LIB_DIR"/bin/*.sh; do
  bash -n "$library"
done
while IFS= read -r tool; do
  bash -n "$tool"
done < <(find "$ROOT_DIR/packages/mac" -type f -name '*.sh' | sort)

[[ ! -e "$INSTALLER_DIR/mac-install.sh" ]] || fail 'old Mac installer still exists'
[[ ! -e "$INSTALLER_DIR/linux-install.sh" ]] || fail 'old Linux installer still exists'

if grep -RIEq 'linuxbrew|migrat(e|ion)|backwards?[ -]?compat' \
  "$INSTALLER_DIR/install.sh" "$INSTALLER_DIR/lib" "$INSTALLER_DIR/setup"; then
  fail 'installer contains an old-system migration or compatibility path'
fi

if grep -RIEq 'ubuntu|gnome|gdm|gsettings|add-apt-repository|(^|[^a-z])snap([^a-z]|$)' \
  "$INSTALLER_DIR/install.sh" "$INSTALLER_DIR/lib" "$INSTALLER_DIR/setup"; then
  fail 'installer contains a removed Linux desktop or package path'
fi

grep -Fq 'https://download.docker.com/linux/debian' \
  "$INSTALLER_DIR/setup/apps/docker.sh" ||
  fail 'Docker must use its Debian repository'
grep -Fq 'stable/debian/${LINUX_CODENAME}' \
  "$INSTALLER_DIR/setup/apps/tailscale.sh" ||
  fail 'Tailscale must use its Debian repository'
if grep -Fq 'apt_install' "$INSTALLER_DIR/setup/system/desktop-environment.sh"; then
  fail 'the desktop check must not install a desktop environment'
fi

main_body="$(sed -n '/^main() {/,/^}/p' "$INSTALLER_DIR/install.sh")"
desktop_line="$(grep -n 'check_linux_desktop' <<<"$main_body" | head -n 1 | cut -d: -f1)"
phase_line="$(grep -n 'run_phase "$mode"' <<<"$main_body" | head -n 1 | cut -d: -f1)"
[[ -n "$desktop_line" && -n "$phase_line" && "$desktop_line" -lt "$phase_line" ]] ||
  fail 'the read-only Linux desktop check must run before normal phases'
system_phase="$(sed -n '/^configure_system() {/,/^}/p' "$INSTALLER_DIR/install.sh")"
grep -Fq "system/display.sh" <<<"$system_phase" ||
  fail 'X11 configuration must stay in the system phase'
check_phase="$(sed -n '/^check_linux_desktop() {/,/^}/p' "$INSTALLER_DIR/install.sh")"
if grep -Fq 'display.sh' <<<"$check_phase"; then
  fail 'the common Linux desktop check must not configure the display server'
fi
finish_install="$(sed -n '/^finish_install() {/,/^}/p' "$INSTALLER_DIR/install.sh")"
grep -Fq '[[ "$mode" == all || "$mode" == system ]] || return 0' <<<"$finish_install" ||
  fail 'only full and system-phase runs may offer to reboot the machine'

vnc_strategy="$INSTALLER_DIR/setup/access/vnc.sh"
grep -Fq '/etc/systemd/system/x11vnc.service' "$vnc_strategy" ||
  fail 'VNC must use a boot-level system service'
grep -Fq -- '-display :0' "$vnc_strategy" ||
  fail 'VNC must share display :0'
grep -Fq '/etc/x11vnc.passwd' "$vnc_strategy" ||
  fail 'VNC must use the root-owned password file'
grep -Fq -- '-localhost' "$vnc_strategy" ||
  fail 'VNC must only listen on localhost for SSH tunneling'
grep -Fq 'retry 10 1 linux_vnc_service_is_ready' "$vnc_strategy" ||
  fail 'VNC readiness must use the shared retry helper'
if grep -Fq 'systemctl --user' "$vnc_strategy"; then
  fail 'VNC must not use a user service'
fi

login_strategy="$INSTALLER_DIR/setup/appearance/login-screen.sh"
grep -Fq '/etc/lightdm/lightdm-gtk-greeter.conf' "$login_strategy" ||
  fail 'login styling must configure the existing LightDM GTK greeter'
grep -Fq '/usr/local/share/backgrounds/machine-login.png' "$login_strategy" ||
  fail 'the LightDM background must be readable outside the user home'
grep -Fq 'hide-user-image=false' "$login_strategy" ||
  fail 'the LightDM login must show the Tux avatar'
grep -Fq 'position=50%,center 50%,center' "$login_strategy" ||
  fail 'the LightDM login must be centered on both axes'
grep -Fq 'greeter-hide-users=false' "$login_strategy" ||
  fail 'the LightDM login must show the real local user'
grep -Fq 'greeter-show-manual-login=false' "$login_strategy" ||
  fail 'the LightDM login must not default to a manual user prompt'
grep -Fq 'last-user=$user' "$login_strategy" ||
  fail 'the LightDM login must select the real local user'
grep -Fq 'render_machine_background' "$login_strategy" ||
  fail 'the LightDM login must use the shared machine-background renderer'
[[ -f "$INSTALLER_DIR/config/xfce/login-screen.css" ]] ||
  fail 'the LightDM login CSS is missing'

icons_strategy="$INSTALLER_DIR/setup/appearance/icons.sh"
grep -Fq '_linux_install_tux' "$icons_strategy" ||
  fail 'the icon step must install the checked Tux artwork'
grep -Fq 'cd503ad510e16ff2869f959cf57b892bb2175a6874ff696b495bd94fd7db9743' \
  "$icons_strategy" || fail 'the Tux SVG checksum is missing'
grep -Fq 'xfconf_set xsettings /Net/IconThemeName string "$theme"' "$icons_strategy" ||
  fail 'icon setup must use the shared Xfce settings helper'

theme_strategy="$INSTALLER_DIR/setup/appearance/theme.sh"
grep -Fq "local theme='WhiteSur-Dark'" "$theme_strategy" ||
  fail 'Linux must use the dark WhiteSur desktop theme'
grep -Fq 'xfce4-notifyd /theme string Rice' "$theme_strategy" ||
  fail 'the dark notification theme must be selected'
grep -Fq 'extract_github_source_archive' "$theme_strategy" ||
  fail 'the desktop theme must use the shared checked-archive helper'
[[ -f "$INSTALLER_DIR/config/xfce/notifications.css" ]] ||
  fail 'the notification CSS is missing'

dock_strategy="$INSTALLER_DIR/setup/desktop/dock.sh"
if grep -Eqi 'plank|dockitem|dconf' "$dock_strategy"; then
  fail 'the Linux dock strategy must not install or configure Plank'
fi
finder_line="$(grep -n "_mac_app '/System/Library/CoreServices/Finder.app'" "$dock_strategy" | cut -d: -f1)"
apps_line="$(grep -n "_mac_app '/System/Applications/Apps.app'" "$dock_strategy" | cut -d: -f1)"
[[ -n "$finder_line" && -n "$apps_line" && "$apps_line" -eq $((finder_line + 1)) ]] ||
  fail 'Apps.app must be immediately after Finder in the macOS Dock'
grep -Fq 'xfconf_set_array xfce4-panel /panels int' "$dock_strategy" ||
  fail 'the lower Xfce panel must be removed through Xfce settings'

top_bar_strategy="$INSTALLER_DIR/setup/desktop/top-bar.sh"
grep -Fq '/usr/local/share/icons/tux.svg' "$top_bar_strategy" ||
  fail 'the top bar must use the checked full-color Tux icon'
grep -Fq "'%b %d  %H:%M'" "$top_bar_strategy" ||
  fail 'the top-bar clock must omit the weekday'
grep -Fq '+restart' "$top_bar_strategy" ||
  fail 'the top-bar user menu must include Restart'
for launcher in thunar.desktop xfce4-terminal.desktop codium.desktop; do
  grep -Fq "$launcher" "$top_bar_strategy" ||
    fail "the top bar is missing $launcher"
done
[[ -f "$INSTALLER_DIR/config/xfce/panel.css" ]] ||
  fail 'the top-bar CSS is missing'

terminal_strategy="$INSTALLER_DIR/setup/apps/terminal.sh"
grep -Fq 'xfconf_set xfce4-terminal /font-name' "$terminal_strategy" ||
  fail 'Linux must configure Xfce Terminal through its live settings channel'
grep -Fq 'xfconf_set xfce4-terminal /misc-borders-default bool true' \
  "$terminal_strategy" ||
  fail 'Xfce Terminal must keep normal window borders and controls'
if grep -Eqi 'ghostty|kitty|alacritty' <(sed -n '/^linux()/,/^}/p' "$terminal_strategy"); then
  fail 'Linux terminal setup must not install or configure another terminal'
fi

sidebar_strategy="$INSTALLER_DIR/setup/files/sidebar.sh"
sidebar_helper="$INSTALLER_DIR/setup/files/finder-sidebar.js"
[[ -f "$sidebar_helper" ]] || fail 'the macOS Finder sidebar helper is missing'
grep -Fq 'finder-sidebar.js' "$sidebar_strategy" ||
  fail 'macOS must use the Finder sidebar script'
grep -Fq 'NSKeyedArchiver.archivedDataWithRootObject' "$sidebar_helper" ||
  fail 'macOS must write Finder sidebar favorites'
grep -Fq 'Privacy_AllFiles' "$sidebar_strategy" ||
  fail 'macOS must offer Full Disk Access when Finder blocks the sidebar'
grep -Fq '"$HOME" "$ROOT_DIR" "$HOME/code"' "$sidebar_strategy" ||
  fail 'macOS must pin the dotfiles repo after Home'
grep -Fq 'file://$ROOT_DIR .dotfiles' "$sidebar_strategy" ||
  fail 'Linux must pin the dotfiles repo as .dotfiles'
if grep -Fq 'leaving the sidebar unchanged' "$sidebar_strategy"; then
  fail 'macOS must not leave an old .config sidebar item in place'
fi

windows_strategy="$INSTALLER_DIR/setup/desktop/windows.sh"
center_fill_config="$INSTALLER_DIR/config/window-management/center-fill.lua"
grep -Fq "ask_choice 'Window management' Skip Disable Enable" "$windows_strategy" ||
  fail 'macOS window management must offer Skip / Disable / Enable'
grep -Fq "ask_choice 'Window configuration' 'Center + Fill'" "$windows_strategy" ||
  fail 'Center + Fill must use a second configuration prompt'
grep -Fq "0) configuration='center-fill'" "$windows_strategy" ||
  fail 'Center + Fill must be stored by its stable center-fill name'
grep -Fq '0) return 0 ;;' "$windows_strategy" ||
  fail 'skipping window management must return before making changes'
grep -Fq 'BEGIN dotfiles installer: window management' "$windows_strategy" ||
  fail 'the Hammerspoon loader must use marked managed lines'
grep -Fq 'com.dotfiles.window-management.hammerspoon.plist' "$windows_strategy" ||
  fail 'Hammerspoon startup must use an installer-owned login file'
grep -Fq 'mac_hammerspoon_has_other_configuration' "$windows_strategy" ||
  fail 'disabling must keep Hammerspoon startup when other configuration remains'
grep -Fq 'open -g "$hammerspoon_app"' "$windows_strategy" ||
  fail 'Hammerspoon must launch by path before macOS can find a fresh install by name'
grep -Fq 'retry 20 0.5 mac_hammerspoon_app' "$windows_strategy" ||
  fail 'a fresh Hammerspoon install must wait for the app bundle to appear'
grep -Fq 'retry 20 0.5 silent open -g "$hammerspoon_app"' "$windows_strategy" ||
  fail 'a fresh Hammerspoon install must retry opening the app'
grep -Fq 'retry 40 0.25 pgrep -x Hammerspoon' "$windows_strategy" ||
  fail 'Hammerspoon startup must be confirmed by its running process'
grep -Fq 'hs.window.animationDuration = 0' "$center_fill_config" ||
  fail 'Center + Fill must disable Hammerspoon window animations'
grep -Fq 'win:isMaximizable() == true' "$center_fill_config" ||
  fail 'Center + Fill must leave fixed-size windows at their original size'
grep -Fq 'local gap = 16' "$center_fill_config" ||
  fail 'Center + Fill must leave a 16-pixel gap around resizable windows'
grep -Fq 'local frame = win:screen():frame()' "$center_fill_config" ||
  fail 'Center + Fill must use the current screen usable frame'
grep -Fq 'w = frame.w - gap * 2' "$center_fill_config" ||
  fail 'Center + Fill must remove the gap from both sides of the window width'
grep -Fq 'h = frame.h - gap * 2' "$center_fill_config" ||
  fail 'Center + Fill must remove the gap from both sides of the window height'
grep -Fq 'win:centerOnScreen(nil, true, 0)' "$center_fill_config" ||
  fail 'Center + Fill must center fixed-size windows without resizing them'
for event in windowCreated windowFocused windowUnminimized; do
  grep -Fq "hs.window.filter.$event" "$center_fill_config" ||
    fail "Center + Fill does not handle $event"
done
grep -Fq 'centerFillWindowWatcher:getWindows()' "$center_fill_config" ||
  fail 'Center + Fill must apply to existing windows when it loads'

machine_name_strategy="$INSTALLER_DIR/setup/desktop/machine-name.sh"
grep -Fq 'silent launchctl print "$service"' "$machine_name_strategy" ||
  fail 'machine-name display must wait for its old launch agent to stop'

wallpaper_strategy="$INSTALLER_DIR/setup/appearance/wallpaper.sh"
grep -Fq 'xfconf-query -c xfce4-desktop' "$wallpaper_strategy" ||
  fail 'Linux wallpaper setup must configure Xfce'
grep -Fq 'xrandr --listactivemonitors' "$wallpaper_strategy" ||
  fail 'Linux wallpaper setup must find the active monitor names'
grep -Fq '/backdrop/screen0/monitor%s/workspace%s/last-image' "$wallpaper_strategy" ||
  fail 'Linux wallpaper setup must create missing monitor and workspace settings'
grep -Fq 'style_property="${property%/last-image}/image-style"' "$wallpaper_strategy" ||
  fail 'Linux wallpaper setup must set the image style'
grep -Fq 'xfdesktop --reload' "$wallpaper_strategy" ||
  fail 'Linux wallpaper setup must reload the active Xfce desktop'
grep -Fq 'render_machine_background' "$wallpaper_strategy" ||
  fail 'wallpaper setup must use the shared machine-background renderer'

grep -Fq 'extract_github_source_archive' "$icons_strategy" ||
  fail 'the icon theme must use the shared checked-archive helper'

if grep -IEqi 'ubuntu|gnome|gdm|gsettings' \
  "$INSTALLER_DIR/README.md" "$INSTALLER_DIR/TESTING.md"; then
  fail 'installer docs still describe the removed Linux target'
fi

# package.json machine-install scripts must invoke install.sh, not setup/*.sh directly.
root_package="$ROOT_DIR/package.json"
if [[ -f "$root_package" ]]; then
  bad_npm="$(grep -E '"install:(git|skills|machine|theme)"' "$root_package" | grep -v 'packages/installer/install\.sh' || true)"
  if [[ -n "$bad_npm" ]]; then
    printf '%s\n' "$bad_npm" >&2
    fail 'package.json install:git|skills|machine|theme must call packages/installer/install.sh'
  fi
  if grep -E '"install:[^"]+"\s*:\s*"bash packages/installer/setup/' "$root_package"; then
    fail 'package.json must not invoke packages/installer/setup/ directly'
  fi
fi

printf 'Strategy shape passed for every setup file.\n'
