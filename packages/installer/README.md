# Machine installer

The repo must live at `~/.dotfiles`. The installer links only the config files and config subfolders each app needs. It does not link whole Ghostty, Neovim, OpenCode, Karabiner, or tmux source folders.

**One entry point:** `packages/installer/install.sh`. Every install path goes through it — full run, phase slices, and single strategies (`--git`, `--skills`, `--theme`). Do not run `packages/installer/setup/**` or `packages/theming/create/controller.ts` yourself for install.

```bash
bash packages/installer/install.sh                 # full machine
bash packages/installer/install.sh --apps          # one phase
bash packages/installer/install.sh --git           # Git only
bash packages/installer/install.sh --skills        # Skills only
bash packages/installer/install.sh --theme         # theme generation + install
npm run install:machine                 # → install.sh
npm run install:git                     # → install.sh --git
npm run install:skills                  # → install.sh --skills
npm run install:theme                   # → install.sh --theme
npm run verify:machine                  # verify installed links after a VM install
```

`--theme` uses Node from `--development` and VSCodium from `--apps`. It loads NVM and Homebrew commands itself, including when it runs from a fresh Bash session.

Normal user only (not root). `sudo` is used where the OS needs it.

The only supported Linux base is **Debian 13 (trixie), amd64 or arm64**. In the Debian installer, select **Xfce**, **SSH server**, and **standard system utilities**. The normal user must have `sudo`. The machine installer expects Xfce, LightDM, and the X11 session to already exist; it does not install or replace the desktop.

- Agents editing this tree: [AGENTS.md](AGENTS.md)
- VM tests: [TESTING.md](TESTING.md)

---

`install.sh` detects the OS, checks the user, then either runs a single strategy or asks for a **machine name and color** (writes gitignored `machine.json`) and walks phases.

`--git`, `--skills`, and `--theme` skip the identity prompt. Phase flags (`--apps`, …) still ask for machine name/color first. No argument = all phases.

Normal phase runs start with a Linux-only desktop check and X11 setup, then use this order: `apps` → `development` → `appearance` → `input` → `desktop` → `files` → `access` → `system`. The check runs before every phase flag, so VNC never runs before LightDM and X11 are ready.

| Phase         | Covers                                                         |
| ------------- | -------------------------------------------------------------- |
| `apps`        | Apps (Homebrew / APT / vendor)                                 |
| `development` | Git, Node, Zsh, tmux, VSCodium, Skills                         |
| `appearance`  | Wallpaper, screen saver, theme, icons, login screen            |
| `input`       | Pointer, touchpad, keyboard, remapping                         |
| `desktop`     | Workspaces, items/widgets, windows, Dock, name in bar, top bar |
| `files`       | Defaults, associations, Finder/Files                           |
| `access`      | Handoff, assistants, headless notes, SSH, VNC                  |
| `system`      | Updates, power, UI refresh                                     |

### Where things live

```
packages/installer/install.sh       **only** machine-install entry point
packages/installer/setup/<phase>/…  strategies (launched by install.sh with OS as $1)
packages/installer/setup/identity.sh before phases (skipped for --git / --skills / --theme)
packages/installer/setup/skills.sh  from development (also --skills)
packages/installer/lib/lib.sh       installer library entry point
packages/installer/tests/           shape + library + installed-link checks
packages/lib/bash/                  standalone reusable Bash library
packages/lib/bash/bin/              standalone cross-OS Bash tools
packages/lib/ts/                    standalone shared TypeScript (empty for now)
packages/mac/                       standalone Mac, Raycast, and Swift tools
packages/theming/                   theme generator, outputs, and VS Code theme package
packages/vscode-ext/                VSCodium extension source and tests
```

### A strategy file

`install.sh` runs each setup file in a **new** Bash process with the OS as `$1`, so every file can define plain `mac()` / `linux()`:

```bash
install_vscodium() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() { brew_cask vscodium; }
linux() { apt_install codium; }

install_vscodium "$1"
```

Source `packages/installer/lib/lib.sh` through the local installer-relative path at the top. It loads `packages/lib/bash/lib.sh` and then the installer-only helpers. Shape is enforced by `npm run install:test` (registration once, both platform functions, `return 0` on skips, no per-file CPU detect, no migration wording).

### Prompts

| Helper       | Use                           |
| ------------ | ----------------------------- |
| `ask_choice` | Numbered menu → 0-based index |
| `ask_binary` | Yes / no                      |

Before setting up a group of links, such as Agent skills or Neovim, the installer checks the whole group. If it finds existing files or links pointing somewhere else, it asks once whether to **Skip** or **Replace with symlinks** for that group. Skip leaves each existing item alone while still creating missing links. It never replaces a real directory.

**Skip / Disable / Enable** is a real triad when those are the labels: `0` skip, `1` disable, `2` enable (SSH, VNC). Everything else keeps domain labels — Dock hide/show, sizes, colors, power Skip/Normal/Server, Tailscale install modes, etc.

### npm scripts

```bash
npm run install:machine  # → install.sh (full)
npm run install:git      # → install.sh --git
npm run install:skills   # → install.sh --skills
npm run install:theme    # → install.sh --theme (theming package; not OS appearance)
npm run install:test     # shape + lib checks (no VM)
```

### Platform quirks

- **Linux:** Debian 13 (trixie) only, with Xfce + LightDM + X11 installed by the Debian installer.
- **Packages:** Homebrew on Mac; APT on Debian unless the vendor has no APT package.
- **Clean only:** no “move my old dotfiles” path.
- **`$LINUX_ARCH`:** set once. amd64 → Chrome; arm64 → Brave.
- **Voice dictation:** VoiceInk on Mac; skipped on Linux.
- **Firefox:** Debian’s `firefox-esr` package.
- **Codex:** Mac installs the ChatGPT app, which now includes Codex; Linux installs the Codex CLI.
- **CleanShot X:** Mac only.
- **Defaults:** Chrome (Mac + Debian amd64) or Brave (Debian arm64); Ghostty as the Debian terminal. Mac shows a system browser prompt — pick **Use Chrome**.
- **Ghostty:** Mac uses Homebrew. Debian uses the checked AppImage release because Debian 13 has no `ghostty` package. Its launcher enables Mesa's OpenGL 4.3 path inside QEMU/UTM so the terminal also opens on the clean test VM.
- **Desktop styling:** Linux offers separate prompts for the machine-color wallpaper, WhiteSur desktop styling, and WhiteSur icons. The desktop phase puts close/minimize/maximize on the left in Mac order, uses a penguin application menu, starts the right status group with the user name, and replaces the lower Xfce panel with a rounded WhiteSur Plank dock. Workspaces stay unchanged. App theme packs still use `--theme`.
- **Login screen:** Debian keeps the LightDM GTK greeter and gives it a machine-color background, no avatar, JetBrains Mono, a centered login, and a minimal status bar. It reuses WhiteSur when selected earlier in the appearance phase and falls back to Adwaita otherwise.
- **Git:** optional; defaults `garrett` / noreply email / `main`; GitHub login is a separate browser step; no token in the shell env.
- **Node:** NVM is installed in `~/.nvm`, including when `XDG_CONFIG_HOME` is set.
- **Desktop check:** `system/desktop-environment.sh` requires `startxfce4`, `/usr/sbin/lightdm`, LightDM as the default display manager, and an Xfce X11 session.
- **Display server:** `system/display-server.sh` sets LightDM’s default session to Xfce and removes other display-session choices. Reboot or sign out to apply it.
- **VNC:** Screen Sharing on Mac; on Debian, a boot-level root `x11vnc` service shares the live X11 display on `:0`, including the LightDM greeter before login. Its password is `/etc/x11vnc.passwd` and it listens on port 5900. If `:0` is down during an SSH install, the enabled service keeps retrying until the display starts.

To keep VNC off the public network, tunnel it through SSH and connect the VNC client to `localhost:5900`:

```bash
ssh -L 5900:localhost:5900 user@debian-host
```
