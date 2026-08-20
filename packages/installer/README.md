# Machine installer

The repo must live at `~/.dotfiles`. The installer links only the config files and config subfolders each app needs. On Mac, that includes Ghostty's config and themes. It does not link whole Ghostty, Neovim, OpenCode, Karabiner, or tmux source folders.

**One entry point:** `packages/installer/install.sh`. Every install path goes through it — full run, phase slices, and single strategies (`--git`, `--agents`, `--theme`). Do not run `packages/installer/setup/**` or `packages/theming/create/controller.ts` yourself for install.

```bash
bash packages/installer/install.sh                 # full machine
bash packages/installer/install.sh --apps          # one phase
bash packages/installer/install.sh --git           # Git only
bash packages/installer/install.sh --agents        # Agent instructions and skills
bash packages/installer/install.sh --theme         # theme generation + install
bash packages/installer/install.sh --retire        # remove recorded packages
npm run install:machine                 # → install.sh
npm run install:git                     # → install.sh --git
npm run install:agents                  # → install.sh --agents
npm run install:theme                   # → install.sh --theme
npm run install:retire                  # → install.sh --retire
npm run verify:machine                  # verify installed links after a VM install
```

`--theme` uses Node from `--development` and VSCodium from `--apps`. It loads NVM and Homebrew commands itself, including when it runs from a fresh Bash session.

Successful full and system-phase runs recommend a reboot and ask whether to
reboot now. The default answer is no. Choosing yes reboots either macOS or
Linux. Smaller phase runs and the Git, agents, and theme commands do not ask.

Normal user only (not root). `sudo` is used where the OS needs it.

The only supported Linux base is **Debian 13 (trixie), amd64 or arm64**. In the Debian installer, select **Xfce**, **SSH server**, and **standard system utilities**. The normal user must have `sudo`. The machine installer expects Xfce, LightDM, and the X11 session to already exist; it does not install or replace the desktop.

- Agents editing this tree: [AGENTS.md](AGENTS.md)
- VM tests: [TESTING.md](TESTING.md)

---

`install.sh` detects the OS and checks the user. A full install also asks for a **machine name and color** (blue, green, orange, purple, red, yellow, aqua, gray, or black), writes the name, color, and resolved hex value to gitignored `machine.json`, and walks all phases.

Single strategies and individual phase flags (`--apps`, `--development`, …) skip machine identity. `--all`, `all`, and no argument run the full install and configure it first.

Normal phase runs start with a read-only Linux desktop check, then use this order: `apps` → `development` → `appearance` → `input` → `desktop` → `files` → `access` → `system`. The check runs before every phase flag, so Linux work only starts after Xfce, LightDM, and X11 are ready. Changes to the LightDM X11 session stay in the system phase.

| Phase         | Covers                                                                                   |
| ------------- | ---------------------------------------------------------------------------------------- |
| `apps`        | Apps (Homebrew / APT / vendor)                                                           |
| `development` | Git, Node, Pi, AWS CLI, Cloudflare CLIs, Zsh, tmux, VSCodium, Codex, MCP servers |
| `appearance`  | Wallpaper, screen saver, theme, icons, login screen                                      |
| `input`       | Pointer, touchpad, keyboard, remapping                                                   |
| `desktop`     | Workspaces, items/widgets, windows, lower panel, top bar, name display                   |
| `files`       | Defaults, associations, Finder/Files                                                     |
| `access`      | Handoff, assistants, headless notes, SSH, VNC                                            |
| `system`      | LightDM X11 session, updates, power, UI refresh                                          |

### Where things live

```
packages/installer/install.sh       **only** machine-install entry point
packages/installer/setup/<phase>/…  strategies (launched by install.sh with OS as $1)
packages/installer/config/          installer-owned configuration loaded by strategies
packages/installer/setup/identity.sh before full or phase installs (skipped for single strategies)
packages/installer/setup/agents.sh  agent configuration and skills (--agents only)
.agents/AGENTS.md                   global instructions shared by Codex and Pi
codex/.codex/                       personal Codex settings linked during development
packages/installer/lib/lib.sh       installer library entry point
packages/installer/tests/           mirrors installer paths (`setup/`, `lib/`, and top-level flow)
packages/lib/bash/                  standalone reusable Bash library
packages/lib/bash/bin/              standalone cross-OS Bash tools
packages/lib/ts/                    standalone shared TypeScript (empty for now)
packages/mac/                       standalone Mac tools and the mactop source
packages/mac/mactop/                canonical mactop source, config, and LaunchAgent
packages/raycast/                   standalone Raycast extensions and shared runner
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

Before setting up a group of links, such as agent configuration or Neovim, the installer checks the whole group. If it finds existing files or links pointing somewhere else, it asks once whether to **Skip** or **Replace with symlinks** for that group. Skip leaves each existing item alone while still creating missing links. It never replaces a real directory.

**Skip / Disable / Enable** is a real triad when those are the labels: `0` skip, `1` disable, `2` enable (SSH, VNC). Everything else keeps domain labels — Dock hide/show, sizes, colors, power Skip/Normal/Server, Tailscale install modes, etc.

On macOS, **Window management** uses the same triad. Skip touches nothing. Disable removes only the installer-managed Hammerspoon loader and `center-fill` state. Enable then asks for a named **Window configuration**; the first configuration is `center-fill`, backed by Hammerspoon. Its rule fills resizable windows inside the menu bar and Dock with a 16-pixel gap around them, centers fixed-size windows without resizing them, and never uses macOS Full Screen. After a first-time Hammerspoon install, the installer waits for both the app and its running process before continuing. The installer preserves other `~/.hammerspoon/init.lua` code and keeps Hammerspoon startup when other Hammerspoon code remains. Accessibility permission must still be granted by the user in System Settings.

### npm scripts

```bash
npm run install:machine  # → install.sh (full)
npm run install:git      # → install.sh --git
npm run install:agents   # → install.sh --agents
npm run install:theme    # → install.sh --theme (theming package; not OS appearance)
npm run install:retire   # → install.sh --retire
npm run test:mactop      # full mactop test, race, vet, build, and shuffle checks
npm run install:test     # shape + lib checks (no VM)
```

Tests mirror the installer tree. Setup checks live under `tests/setup/<phase>/`,
library checks under `tests/lib/`, top-level installer-flow checks at the tests
root, and repository/link checks under `tests/repository/`.

### Agent settings and skills

Agent setup is separate from development setup. It links `.agents/AGENTS.md`
to Codex, Pi, and Claude Code. It also links `.agents/CLAUDE.md` to Claude
Code and links the shared skills to every supported agent harness. Codex
configuration remains part of development setup.

On another machine, clone or pull the repo at `~/.dotfiles`, then run
`bash packages/installer/install.sh --agents`. Later pulls update the
linked files without recreating the links.

Full and development installs do not run agent setup. Run `--agents`
separately when you need these links.

Run `bash packages/installer/install.sh --apps` separately to install Claude
Code.

### Global MCP servers

Development setup registers global MCP servers with Codex and Claude Code.
Server definitions and add instructions live in
[`setup/development/mcp-servers.sh`](setup/development/mcp-servers.sh), with
focused checks in
[`tests/setup/development/mcp-servers.sh`](tests/setup/development/mcp-servers.sh).

### Platform quirks

- **Linux:** Debian 13 (trixie) only, with Xfce + LightDM + X11 installed by the Debian installer.
- **Packages:** Homebrew on Mac; APT on Debian unless the vendor has no APT package. Development installs the AWS CLI plus Cloudflare's `cloudflared` and `wrangler` CLIs.
- **Retire:** `retire name` records and uninstalls a package. Full installs and `--retire` remove recorded packages for the current platform.
- **Clean only:** no “move my old dotfiles” path.
- **`$LINUX_ARCH`:** set once. amd64 → Chrome; arm64 → Brave.
- **Voice dictation:** VoiceInk on Mac; skipped on Linux.
- **Firefox:** Debian’s `firefox-esr` package.
- **Codex:** Mac installs both the ChatGPT app and Codex CLI; Linux installs the Codex CLI. The Mac ChatGPT launcher switches away immediately when ChatGPT is already frontmost.
- **Pi:** Mac and Linux install the Pi coding agent after Node.js into `~/.local/bin`, which stays on `PATH` when NVM changes Node versions.
- **T3 Code:** Mac and Linux install the npm server CLI after Node.js. Run `t3-serve`, for the headless local web app; the desktop application is not installed.
- **System monitor:** Mac builds the repository-owned source in `packages/mac/mactop` with Go into `~/.local/bin/mactop`, links its monochrome menu-bar configuration into `~/.mactop`, and starts that build at login through a quiet pseudo-terminal because mactop still opens `/dev/tty`. Linux installs Xfce Task Manager.
- **CleanShot X:** Mac only.
- **Browsers:** Mac installs Chrome and Arc, with Chrome as the default, and links Arc's Air Traffic Control routing file from `arc/StorableLinkRouting.json`. The routing file contains Arc Space IDs and is Mac-only. Arc may replace the link when it saves routing changes, so rerun the apps phase if that happens. Debian amd64 installs Chrome; Debian arm64 installs Brave. Debian keeps Xfce Terminal as installed by the OS. Mac shows a system browser prompt — pick **Use Chrome**.
- **Dock:** The Mac Dock starts with Finder and Apps, followed by Mission Control, Settings, Ghostty, VSCodium, and Chrome.
- **File browser:** Finder and Thunar always show hidden files. Their sidebars pin `~/.dotfiles` after Home, followed by `~/code` and the standard folders.
- **File associations:** `npm run install:file-ext` separately sets common source and text extensions, including JSON, to open in VSCodium on Mac and Linux. On Mac, it uses the supported `NSWorkspace` and Uniform Type Identifiers APIs, requests approval when macOS requires it, and verifies the Finder handler. The normal machine installer does not change these associations.
- **Terminal:** Mac installs and configures Ghostty through Homebrew. Debian keeps Xfce Terminal and gives it the rice font, colors, and minimal controls through Xfce's live settings, without installing another terminal or changing the launcher command.
- **Desktop styling:** Linux offers separate prompts for the machine-color wallpaper, WhiteSur Dark styling, and WhiteSur icons. The desktop uses Inter for its UI and JetBrains Mono only for monospace text, hides desktop icons, puts close/minimize/maximize on the left, removes the lower panel, and builds one compact dark top bar. Full-color Tux opens the application menu. A Docklike Taskbar pins Files, Terminal, VSCodium, and the installed Chrome-family browser, and it groups and focuses their open windows. The right side shows the machine name, compact two-line CPU/GPU/memory readouts, the tray, and a date/time with seconds but no weekday. GPU use appears only when an NVIDIA or AMD GPU and its driver are available inside the guest. Restart is in the machine-name menu. There is no Plank. Workspaces stay unchanged. App theme packs still use `--theme`.
- **Login screen:** Debian keeps the LightDM GTK greeter and gives it the machine-color background, a centered dark login card, the real local user, a full-color Tux avatar, Inter, and a small top status bar. The hostname and extra session controls stay out of the bar.
- **Tux artwork:** The checked panel and login images come from the canonical [Tux file on Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Tux.svg), credited there to Larry Ewing, Simon Budig, and Garrett LeSage.
- **Git:** optional; defaults `garrett` / noreply email / `main`; GitHub login is a separate browser step; no token in the shell env.
- **Node:** NVM is installed in `~/.nvm`, including when `XDG_CONFIG_HOME` is set.
- **Zsh:** Development setup links `.zshenv`, `.zprofile`, and `.zshrc` from `zsh/`. Zsh silently selects the nearest `.nvmrc`, or the NVM default when none exists, at startup. It applies that same rule after a directory change, announcing the switch, so leaving a project restores the default instead of keeping its Node. Login and interactive setup preserve that selection while completion stays in `.zshrc`. On Linux, the right prompt reuses the Xfce system-stats collector for CPU, GPU, and memory use.
- **Desktop check:** `system/desktop-environment.sh` requires `startxfce4`, `/usr/sbin/lightdm`, LightDM as the default display manager, and an Xfce X11 session.
- **Display server:** `system/display.sh` sets LightDM’s default session to Xfce and removes other display-session choices. Reboot or sign out to apply it.
- **VNC:** Screen Sharing on Mac; on Debian, a boot-level root `x11vnc` service shares the live X11 display on `:0`, including the LightDM greeter before login. Its password is `/etc/x11vnc.passwd` and it listens only on localhost port 5900. If `:0` is down during an SSH install, the enabled service keeps retrying until the display starts.

To keep VNC off the public network, tunnel it through SSH and connect the VNC client to `localhost:5900`:

```bash
ssh -L 5900:localhost:5900 user@debian-host
```
