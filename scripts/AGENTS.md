# Scripts Directory — Agent Rules

This directory contains one macOS/Ubuntu installer plus separate Mac-only tools.

## Workflow

1. Keep this file up to date when script layout or conventions change.
2. Whitelist every new tracked file in the root `.gitignore`.
3. Test installer changes only inside clean UTM machines.

## Structure

- `install.sh` — The only installer entry point. It detects macOS or Ubuntu.
- `lib/lib-install.sh` — Small helpers used by the installer.
- `setup/` — One strategy file per app or setting. Each file keeps its Mac and Linux commands together.
  - `setup/apps/` — Application installs.
  - `setup/development/` — Development tool setup.
  - `setup/appearance/` — Wallpaper, screen saver, and theme.
  - `setup/input/` — Pointer, touchpad, keyboard, and key remapping.
  - `setup/desktop/` — Workspaces, desktop items, windows, Dock, and top bar.
  - `setup/files/` — File associations and file browser settings.
  - `setup/access/` — Handoff, assistants, SSH, and screen sharing.
  - `setup/system/` — Updates, power, and final desktop refresh.
- `shared/tools/` — Shared commands used outside the main installer.
- `mac/` — Mac-only tools that are not part of machine setup.
- Root `machine.json` — Ignored, machine-local name and color created by the installer.

## Conventions

- `install.sh` and executable tools use `set -euo pipefail`.
- Use Bash because a clean machine does not have Node.js yet.
- Name the switch function after the thing it changes, such as `install_vscodium` or `configure_dock`.
- Every strategy file receives the OS as `$1`; its switch calls plain `mac()` or `linux()` functions.
- Run each strategy in a new Bash process. This lets every file use the plain names `mac()` and `linux()` without clashes.
- Keep one feature per strategy file. Do not group Skills, Node, Zsh, tmux, Dock, or other unrelated work.
- Do not add migration steps, old-path cleanup, or compatibility branches. These installers target clean machines.
- macOS uses Homebrew. Ubuntu uses APT unless the vendor does not publish an APT package.
- Ubuntu support is limited to Ubuntu 26.04 on amd64 because Google does not publish Chrome for Linux ARM.
- Keep true Mac-only tools under `mac/`; do not put normal Mac setup there.
