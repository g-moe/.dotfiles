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
xfconf-query -c xfce4-panel -lv | grep -E 'pager|tasklist'
dconf read /net/launchpad/plank/docks/dock1/theme
test -d ~/.themes/WhiteSur-Light/xfwm4
test -d ~/.local/share/icons/WhiteSur
test -f ~/.local/share/plank/themes/WhiteSur/dock.theme
test -f ~/.config/autostart/plank.desktop
```

The first four commands must print `WhiteSur-Light`, `WhiteSur-Light`,
`WhiteSur`, and `CHM|`. The `grep` command must print nothing and the Plank
command must print `WhiteSur`. The top panel must use an icon-only application
menu, the lower XFCE panel must be gone, and Plank must have a rounded
translucent background. Workspaces and wallpaper must stay unchanged.

For VNC **Enable**:

```bash
sudo systemctl is-enabled x11vnc.service
sudo systemctl is-active x11vnc.service
sudo ss -ltnp | grep ':5900'
```

Connect once while LightDM is showing, then log in through that VNC connection and confirm it stays on the same `:0` desktop. Confirm local mouse and keyboard changes are visible in VNC and VNC input is visible locally. For **Disable**, the service must be disabled and stopped. For **Skip**, its prior state must not change.

## Current proof status

| Check                          | macOS | Debian 13 |
| ------------------------------ | ----- | --------- |
| No-VM installer tests          | Pass  | Pass      |
| Clean full install             | Kept  | Pass      |
| Reboot and second full install | Kept  | Pass      |
| Xfce + LightDM + X11 check     | n/a   | Pass      |
| WhiteSur desktop + icons       | n/a   | Pass      |
| Rounded Plank dock             | n/a   | Pass      |
| Mac controls + clean top panel | n/a   | Pass      |
| VNC Skip / Disable / Enable    | Kept  | Pass      |
| amd64 package paths            | n/a   | Code only |
| arm64 full UTM proof           | n/a   | Pass      |

WhiteSur supplies the GTK styling, icons, Xfce window frame, and Plank dock
theme. Close, minimize, and maximize are placed on the left in Mac order. The
top panel uses an icon menu and status items without window or workspace lists.
Xfce input, workspace, and wallpaper stay unchanged. Application theme packs
from `--theme` remain separate.

## Pass checklists

**Debian desktop** — LightDM owns the login screen; the session is X11; Xfce opens; optional WhiteSur desktop styling and icons apply; Mac-order window buttons are on the left; the top panel has no open-window list; the rounded Plank dock opens the pinned apps and shows running apps; workspaces and wallpaper stay put; browser and Ghostty defaults work; apps open; VSCodium/`code`, files, SSH, VNC, updates, power, and Skills work; no extra desktop session is offered.

**Git** — `npm run install:git` / `install.sh --git` only; skip leaves Git alone; accept → LFS + filters; name/email/branch stick; settings match `git.sh`; GitHub skip vs browser login; no `GITHUB_TOKEN` in a new shell.

## Known limits

- Mac UTM: Docker installs; engine needs nested virt (unavailable).
- Debian UTM: virtual-machine apps may not run guests without nested virt.
- macOS: protected associations / Finder sidebar — installer skips instead of fighting prompts.

## Recent full proofs

Debian 13 arm64 passed in UTM on July 16, 2026. The first run found and fixed
two live issues: terminal-default verification tried to launch Ghostty over
SSH, and disabling x11vnc left a stale failed service state. The full rerun,
post-reboot rerun, Xfce X11 session, LightDM greeter-to-desktop VNC connection
on `:0`, and the VNC Skip / Disable / Enable choices then passed. A later
appearance-only run and repeat run installed WhiteSur icons and window frames.
A desktop-phase repeat caught and fixed an empty-list bug. A researched styling
pass then applied WhiteSur Light to GTK and Xfwm, made the application menu
icon-only, removed the task and workspace lists, and replaced the lower Xfce
panel with Plank using WhiteSur's rounded dock theme. The official theme text
was copied from the pinned WhiteSur source without cloning another repository.
The final repeat and reboot kept `CHM|` controls on the left, the top status bar
clean, and the rounded dock running. Thunar, VSCodium, Brave, and Ghostty were
checked from the dock. Ghostty's first launch exposed QEMU's OpenGL 3.3 report;
the Debian launcher now selects Mesa's working 4.3 path inside virtual machines.
