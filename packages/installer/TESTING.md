# Clean install checks

Full installer proof runs in **UTM only** — never on the main Mac.

No-VM sanity anytime:

```bash
npm run install:test
```

---

## Hard rules

1. Run install **only** via `bash packages/installer/install.sh` (or `npm run install:machine` / `install:git` / `install:skills` / `install:theme`). Never call `packages/installer/setup/…` or `packages/theming/create/controller.ts` directly for install.
2. One stopped **base** per OS (OS installed, this repo’s installer never run on it).
3. Every first-run test = **disposable clone**. Base stays stopped and untouched.
4. Clone the repo to **exactly** `~/.dotfiles` inside the guest (not a read-only share). The installer rejects every other location.
5. macOS: log into the desktop before you start.
6. Save the full terminal log (host `.test-logs/`, gitignored).
7. Pass once → reboot same clone → run the **same** command again → check again.
8. Pass = commands OK **and** desktop matches the checklist.
9. Then delete the clone (or restore the snapshot for the next run).
10. Iterate with `bash packages/installer/install.sh --<phase>`; finals use no arg.

## Guests

|             | macOS 26           | Debian 13 (trixie)                     |
| ----------- | ------------------ | -------------------------------------- |
| Virt        | Native Apple arm64 | Native Apple Silicon                   |
| User / name | `m4` / `m4-vm`     | `m4` / `m4-vm`                         |
| Notes       | FileVault off      | Xfce + SSH tasks; normal user has sudo |

### Debian installer checklist

1. Install Debian 13 (trixie).
2. Create a normal user with `sudo` access. Leaving the root password empty makes the first user the admin during a normal Debian install.
3. At software selection, choose **Xfce**, **SSH server**, and **standard system utilities**. Do not choose another desktop.
4. Boot to the LightDM login screen and confirm the Xfce desktop opens.
5. Stop the VM and keep it as the untouched `clean-base`.

The installer must find `startxfce4`, `/usr/sbin/lightdm`, `/etc/X11/default-display-manager` pointing to LightDM, and an Xfce session under `/usr/share/xsessions/`.

## Recipe

1. Clone from `clean-base`. Leave the base stopped and untouched.
2. Boot and log into the desktop once.
3. Clone the repo to `~/.dotfiles` in the guest.
4. Run `npm run install:test`, then run the phase or full installer only through `packages/installer/install.sh`.
5. Run the checks below and `npm run verify:machine`.
6. Reboot, run the same installer command again, and repeat the checks.
7. Copy logs to the host, stop the VM, and delete the clone.

## Debian checks

```bash
grep -E '^(ID|VERSION_ID|VERSION_CODENAME)=' /etc/os-release
cat /etc/X11/default-display-manager
systemctl is-active lightdm.service
find /usr/share/wayland-sessions -type f -name '*.desktop' 2>/dev/null
```

The last command must print nothing. After login, the session must be X11:

```bash
loginctl show-session "$XDG_SESSION_ID" -p Type -p Name -p State
```

When WhiteSur window decorations and icons are enabled:

```bash
xfconf-query -c xsettings -p /Net/ThemeName
xfconf-query -c xfwm4 -p /general/theme
xfconf-query -c xsettings -p /Net/IconThemeName
xfconf-query -c xfwm4 -p /general/button_layout
xfconf-query -c xfce4-desktop -p /desktop-icons/style
xfconf-query -c xfce4-notifyd -p /theme
test -d ~/.themes/WhiteSur-Dark/xfwm4
test -d ~/.local/share/icons/WhiteSur
```

The six values must print `WhiteSur-Dark`, `WhiteSur-Dark`, `WhiteSur`, `CHM|`,
`0`, and `Rice`. Thunar must use the same dark GTK theme. Workspaces must stay
unchanged; wallpaper and the top bar are checked separately below.

For the single top bar:

```bash
xfconf-query -c xfce4-panel -p /panels
xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids
xfconf-query -c xfce4-panel -p /plugins/plugin-1/button-icon
xfconf-query -c xfce4-panel -p /plugins/plugin-8/digital-time-format
xfconf-query -c xfce4-panel -p /plugins/plugin-10/items | grep -Fx '+restart'
xfconf-query -c xfce4-panel -lv | grep -E 'pager|tasklist'
test -f ~/.config/xfce4/panel/launcher-11/thunar.desktop
test -f ~/.config/xfce4/panel/launcher-12/xfce4-terminal.desktop
test -f ~/.config/xfce4/panel/launcher-13/codium.desktop
test -f ~/.config/gtk-3.0/gtk.css
test ! -e ~/.config/autostart/plank.desktop
grep -Fq "file://$HOME/.dotfiles .dotfiles" ~/.config/gtk-3.0/bookmarks
grep -Fq "file://$HOME/.dotfiles .dotfiles" ~/.config/gtk-4.0/bookmarks
! dpkg-query -W plank 2>/dev/null
```

The panel list must contain only `1`. The plugin order must be application menu,
Files, Terminal, VSCodium, browser, expanding space, user menu, tray, and clock
with their separators. The icon path must be `/usr/local/share/icons/tux.svg`.
The clock format must be `%b %d  %H:%M`, the Restart line must print, and the
pager/tasklist check must print nothing. Click all four launchers and confirm
the right app opens. The lower panel and Plank must be absent.

For Xfce Terminal:

```bash
xfconf-query -c xfce4-terminal -p /font-name
xfconf-query -c xfce4-terminal -p /misc-menubar-default
xfconf-query -c xfce4-terminal -p /misc-toolbar-default
xfconf-query -c xfce4-terminal -p /misc-borders-default
xfconf-query -c xfce4-terminal -p /scrolling-bar
xfconf-query -c xfce4-terminal -p /color-background
```

It must use JetBrains Mono 12, hide the menu bar and toolbar, hide the scroll
bar, keep normal window borders and controls, and use the dark `#111817`
background. These values must come from the live `xfce4-terminal` settings
channel; current Xfce Terminal only imports `terminalrc` before that channel
exists.

When the machine-color wallpaper is enabled:

```bash
xfconf-query -c xfce4-desktop -lv | grep -E '/(last-image|image-style) '
find ~/.dotfiles -maxdepth 1 -type f -name '.machine-wallpaper-*.png' -size +0c
```

Every `last-image` entry must point to the generated machine wallpaper, every
matching `image-style` entry must be `5`, and the desktop must show the same
machine-color artwork used on macOS. The installer creates missing entries for
every connected monitor and workspace, so a changed display name cannot leave
Xfce using its default wallpaper.

For the styled LightDM login screen:

```bash
grep -E '^(background|theme-name|icon-theme-name|font-name|position|hide-user-image|indicators)=' \
  /etc/lightdm/lightdm-gtk-greeter.conf
test -s /usr/local/share/backgrounds/machine-login.png
test -s /usr/local/share/icons/tux.svg
test -s /var/lib/AccountsService/icons/"$(id -un)".png
sudo grep -F "Icon=/var/lib/AccountsService/icons/$(id -un).png" \
  /var/lib/AccountsService/users/"$(id -un)"
grep -F 'greeter-hide-users=false' /etc/lightdm/lightdm.conf.d/90-rice-greeter.conf
grep -F 'greeter-show-manual-login=false' /etc/lightdm/lightdm.conf.d/90-rice-greeter.conf
sudo grep -F "last-user=$(id -un)" /var/lib/lightdm/.cache/lightdm-gtk-greeter/state
test -s /var/lib/lightdm/.config/gtk-3.0/gtk.css
```

After reboot or sign out, confirm the machine-color background, centered dark
card, selected real local user, full-color Tux avatar, JetBrains Mono, and small
top bar appear. The card must be centered on both axes. The top bar must not
show the hostname, manual `Other...` login, or extra session choices.

For VNC **Enable**:

```bash
sudo systemctl is-enabled x11vnc.service
sudo systemctl is-active x11vnc.service
sudo ss -ltnp | grep ':5900'
```

Connect once while LightDM is showing, then log in through that VNC connection and confirm it stays on the same `:0` desktop. Confirm local mouse and keyboard changes are visible in VNC and VNC input is visible locally. For **Disable**, the service must be disabled and stopped. For **Skip**, its prior state must not change.

## macOS window-management checks

After the desktop phase, confirm Apps is immediately after Finder in the Dock,
followed by Mission Control, Settings, Ghostty, VSCodium, and Chrome.

Run the desktop phase three times on a disposable macOS guest. For **Skip**, compare Hammerspoon, `~/.hammerspoon`, login items, and running processes before and after; nothing may change. For **Enable**, select **Center + Fill**, grant Hammerspoon Accessibility permission yourself, and check:

```bash
cat ~/.hammerspoon/.dotfiles-window-configuration
grep -n 'dotfiles installer: window management' ~/.hammerspoon/init.lua
grep -c 'BEGIN dotfiles installer: window management' ~/.hammerspoon/init.lua
plutil -lint ~/Library/LaunchAgents/com.dotfiles.window-management.hammerspoon.plist
pgrep -x Hammerspoon
```

The stored name must be `center-fill`, both marked loader lines must appear, the `BEGIN` count must be `1`, the login file must be valid, and Hammerspoon must be running. On a clean first install, Enable must wait for the app and process and finish without a second installer run. Add user-owned Lua above and below the marked block, rerun Enable, and confirm the user code stays intact and the loader is not duplicated. Repeat once with `init.lua` as a symlink and confirm the symlink remains in place.

Open a normal resizable window and confirm it fills the current screen inside the menu bar and Dock with a 16-pixel gap on every side, without entering Full Screen or another Space. Open a fixed-size dialog and confirm its size stays unchanged while it moves to the center. Repeat with a window on another screen, a newly opened window, a focused window, and a window restored from the Dock. There must be no movement animation or tiling.

For **Disable**, confirm the managed lines and saved name are gone and Hammerspoon reloads when it was running. User Lua must remain. The installer login file must be removed when no other Hammerspoon code remains and kept when other Hammerspoon code remains. Hammerspoon itself and other window tools must remain installed and unchanged.

## File sidebar checks

After the files phase, Finder on macOS and Thunar on Debian must show
`.dotfiles` immediately after Home, followed by `code`. Neither sidebar may
show `.config` in that position. The Debian bookmark commands above check both
GTK bookmark files. Check Finder visually after the first run and the repeat.

## Current proof status

| Check                          | macOS | Debian 13 |
| ------------------------------ | ----- | --------- |
| No-VM installer tests          | Pass  | Pass      |
| Clean full install             | Pass  | Pass      |
| Reboot and second full install | Pass  | Pass      |
| Xfce + LightDM + X11 check     | n/a   | Pass      |
| WhiteSur Dark + icons          | n/a   | Pass      |
| Machine-color wallpaper        | Pass  | Pass      |
| Dark top bar + app launchers   | n/a   | Pass      |
| Tux login + centered dark card | n/a   | Pass      |
| VNC Skip / Disable / Enable    | Kept  | Pass      |
| `.dotfiles` file sidebar       | Code  | Code      |
| Window management              | Code  | n/a       |
| amd64 package paths            | n/a   | Code only |
| arm64 full UTM proof           | n/a   | Pass      |

WhiteSur Dark supplies the GTK styling, icons, and Xfce window frame. Close,
minimize, and maximize are placed on the left in Mac order. Linux uses one dark
top panel with a Tux menu, four direct app launchers, compact status items, and
no window or workspace list. The lower panel and Plank are absent. Xfce input
and workspace settings stay unchanged. The appearance phase can set the same
generated machine-color wallpaper used on macOS. Application theme packs from
`--theme` remain separate.

## Pass checklists

**Debian desktop** — LightDM owns the styled login screen; the session is X11; Xfce opens; the optional machine-color wallpaper, WhiteSur Dark styling, and icons apply; Mac-order window buttons are on the left; desktop icons and the lower panel are gone; the single top bar has Tux, four working app launchers, the user menu with Restart, tray, and weekday-free clock; workspaces stay put; the browser default works and Xfce Terminal opens with its dark minimal settings; apps open; VSCodium/`code`, files, SSH, VNC, updates, power, and Skills work; no extra desktop session is offered.

**Git** — `npm run install:git` / `install.sh --git` only; skip leaves Git alone; accept → LFS + filters; name/email/branch stick; settings match `git.sh`; GitHub skip vs browser login; no `GITHUB_TOKEN` in a new shell.

## Known limits

- Mac UTM: Docker installs; engine needs nested virt (unavailable).
- Debian UTM: virtual-machine apps may not run guests without nested virt.
- macOS: protected file associations — installer skips instead of fighting prompts.

## Recent full proofs

On July 18, 2026, the macOS sidebar setup restored its earlier JavaScript
writer and Full Disk Access retry so macOS 26 can replace the old `.config`
favorite with `.dotfiles`. Linux now has checks that require the same
`.dotfiles` bookmark in both GTK bookmark files. The no-VM installer tests pass;
clean VM proof of these sidebar checks is pending.

On July 18, 2026, a fresh Hammerspoon install exposed a macOS app-name lookup
delay, and the same run exposed a launchd stop/start race in the machine-name
menu item. Window management now opens the installed app by its exact path,
waits for the app bundle and running process, and reports a clear failure if
either never appears. The menu item waits for its old process to stop before
starting again. The no-VM installer tests passed; another clean Hammerspoon
install is pending.

The finished Linux rice was added to the installer and passed a clean Debian 13
arm64 full install, saved setting checks, reboot, login-screen check, desktop
check, launcher checks, and full repeat on July 18, 2026. The final login screen
showed the real user with the full-color Tux avatar on a centered dark card.
The desktop used WhiteSur Dark, the machine-color wallpaper, one dark top bar,
working Files, Terminal, VSCodium, and Brave launchers, Restart in the user
menu, and no lower panel or Plank. Thunar and Xfce Terminal opened dark.

The same installer changes then passed a clean macOS 26 arm64 full install,
installed-link checks, reboot, full repeat, and repeat installed-link checks in
UTM on July 18, 2026. The Linux-only rice steps did not change the macOS desktop
path.

macOS 26 arm64 passed a clean full install, reboot, full repeat, and installed-link
checks in UTM on July 17, 2026. Before the repeat, two Neovim links and two
Agent skill links were replaced with regular files. The repeat asked once for
Neovim and once for Agent skills, replaced both files in each group, and left
every installed link valid. The available Debian base was already installed,
so its July 17 run was a full repeat rather than a clean proof. It passed the
same grouped-link test, a reboot and second full run, installed-link checks,
the Xfce X11 desktop, the earlier LightDM styling, Plank, SSH, and VNC. That
Plank-based desktop was superseded by the single-panel rice above.

Debian 13 arm64 passed in UTM on July 16, 2026. The first run found and fixed
two live issues: terminal-default verification tried to launch Ghostty over
SSH, and disabling x11vnc left a stale failed service state. The full rerun,
post-reboot rerun, Xfce X11 session, LightDM greeter-to-desktop VNC connection
on `:0`, and the VNC Skip / Disable / Enable choices then passed. A later
appearance-only run and repeat run installed WhiteSur icons and window frames.
A desktop-phase repeat caught and fixed an empty-list bug. A later styling pass
proved the earlier WhiteSur Light and Plank setup before it was replaced by the
current dark single-panel rice. The earlier LightDM screen also passed a full
run, reboot, and repeat before the new Tux login replaced it. The current login
screen and restored Xfce wallpaper are covered by the July 18 proof above.
