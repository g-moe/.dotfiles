# Machine installer

The repo must live at `~/.dotfiles`. The installer links only the config files and config subfolders each app needs. On Mac, that includes Ghostty's config and themes. It does not link whole Ghostty, Neovim, Karabiner, or tmux source folders.

**One entry point:** `packages/installer/install.sh`. Every install path goes through it — full run, phase slices, and single strategies (`--git`, `--agents`, `--theme`). Do not run `packages/installer/setup/**` or `packages/theming/create/controller.ts` yourself for install.

```bash
bash packages/installer/install.sh                 # full machine
bash packages/installer/install.sh --apps          # one phase
bash packages/installer/install.sh --git           # Git only
bash packages/installer/install.sh --agents        # Agent instructions and skills
bash packages/installer/install.sh --theme         # theme generation + install
bash packages/installer/install.sh --retire        # remove recorded packages
bash packages/installer/install.sh --zed           # Zed settings and keymap only
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

- Test commands and layout: [TESTING.md](TESTING.md)

---

`install.sh` detects the OS and checks the user. A full install also asks for a **machine name and color** (blue, green, orange, purple, red, yellow, aqua, gray, or black), writes the name, color, and resolved hex value to gitignored `machine.json`, and walks all phases.

Single strategies and individual phase flags (`--apps`, `--development`, …) skip machine identity. `--all`, `all`, and no argument run the full install and configure it first.

Normal phase runs start with a read-only Linux desktop check, then use this order: `apps` → `development` → `appearance` → `input` → `desktop` → `files` → `access` → `system`. The check runs before every phase flag, so Linux work only starts after Xfce, LightDM, and X11 are ready. Changes to the LightDM X11 session stay in the system phase.

| Phase         | Covers                                                                 |
| ------------- | ---------------------------------------------------------------------- |
| `apps`        | Apps (Homebrew / APT / vendor)                                         |
| `development` | Development tools, coding CLIs, shell, and editor settings             |
| `agents`      | Shared instructions, Claude settings, skills, usage CLI, and MCP tools |
| `appearance`  | Wallpaper, screen saver, theme, icons, login screen                    |
| `input`       | Pointer, touchpad, keyboard, remapping                                 |
| `desktop`     | Workspaces, items/widgets, windows, lower panel, top bar, name display |
| `files`       | Defaults, associations, Finder/Files                                   |
| `access`      | Handoff, assistants, headless notes, SSH, VNC                          |
| `system`      | LightDM X11 session, updates, power, UI refresh                        |

### Where things live

```
packages/installer/install.sh       **only** machine-install entry point
packages/installer/setup/<phase>/…  strategies (launched by install.sh with OS as $1)
packages/installer/config/          installer-owned configuration loaded by strategies
packages/installer/setup/identity.sh machine name and color (full installs only)
packages/installer/setup/agents.sh  agent configuration and usage CLI (--agents only)
.agents/AGENTS.md                   global instructions shared by Codex, Pi, and Claude Code
claude/settings.json                personal Claude Code settings linked during agent setup
codex/.codex/                       personal Codex settings linked during development
packages/installer/lib/lib.sh       installer library entry point
packages/installer/tests/           mirrors installer paths (`setup/`, `lib/`, and top-level flow)
packages/lib/bash/                  standalone reusable Bash library
packages/lib/bash/bin/              standalone cross-OS Bash tools
packages/lib/ts/                    standalone shared TypeScript (empty for now)
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

Source `packages/installer/lib/lib.sh` through a path relative to the setup file.
See the [Bash package README](../lib/bash/README.md) for library structure,
entry points, and shared behavior. `npm run install:test` checks strategy structure.

### Agent settings and skills

Agent setup is separate from development setup. It links `.agents/AGENTS.md`
to Codex, Pi, and Claude Code. It also links `.agents/CLAUDE.md` to Claude
Code and `claude/settings.json` to Claude Code's user settings. On each run, it
replaces the installed contents of the Agents, Codex, Claude Code, and Cursor
skill folders with links to the current shared skills. Codex's internal
`.system` skill directory is preserved. The command stops before cleanup when
the repository has no valid skills. Codex configuration remains part of
development setup.

On another machine, clone or pull the repo at `~/.dotfiles`, then run
`bash packages/installer/install.sh --agents`. Later pulls update linked files.
Run the command again after adding, renaming, archiving, or removing a skill so
the installed skill folders are replaced with the current set.

Full and development installs do not run agent setup. Run `--agents`
separately when you need these links.

Run `bash packages/installer/install.sh --apps` separately to install Claude
Code.

### Global MCP servers

Agent setup registers the pinned Chrome DevTools MCP server globally with
Codex, Claude Code, and Cursor. npm installs the server once globally, and
[`setup/agents/mcp-servers.sh`](setup/agents/mcp-servers.sh) passes the
same absolute server command to each client. Focused checks live in
[`tests/setup/agents/mcp-servers.sh`](tests/setup/agents/mcp-servers.sh).
