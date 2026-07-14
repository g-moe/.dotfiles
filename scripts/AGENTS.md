# Scripts Directory — Agent Rules

This directory contains one macOS/Ubuntu installer plus separate Mac-only tools.

## Workflow

1. Keep this file up to date when script layout or conventions change.
2. Whitelist every new tracked file in the root `.gitignore`.
3. Test installer changes only inside clean UTM machines.

## Structure

- `install.sh` — The only installer entry point. It detects macOS or Ubuntu.
- `lib/lib-install.sh` — The one shared library entry point used by setup files.
- `lib/lib-logging.sh`, `lib/lib-interactive.sh`, `lib/lib-utils.sh`, and `lib/lib-packages.sh` — Focused logging, prompt, safe-link, download, and package helpers.
- `setup/` — One strategy file per app or setting. Each file keeps its Mac and Linux commands together.
  - `setup/apps/` — Application installs.
  - `setup/development/` — Development tool setup.
  - `setup/appearance/` — Wallpaper, screen saver, theme, and Linux icons.
  - `setup/input/` — Pointer, touchpad, keyboard, and key remapping.
  - `setup/desktop/` — Workspaces, desktop items, windows, Dock, and top bar.
  - `setup/files/` — Default applications, file associations, and file browser settings.
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
- Register every strategy exactly once in `install.sh`; `tests/strategy-shape.sh` checks this.
- Keep shared helpers in their matching library and expose them through `lib-install.sh`; do not copy helpers into setup files.
- Keep one feature per strategy file. Do not group Skills, Node, Zsh, tmux, Dock, or other unrelated work.
- Do not add migration steps, old-path cleanup, or compatibility branches. These installers target clean machines.
- macOS uses Homebrew. Ubuntu uses APT unless the vendor does not publish an APT package.
- Ubuntu 26.04 supports amd64 and arm64. `detect_os` exports `LINUX_ARCH` once; setup files must use it instead of detecting the CPU again.
- Use Google Chrome and OpenWhispr on amd64. Use Brave and whisper.cpp on arm64 because those vendors do not publish matching Linux ARM builds.
- Keep true Mac-only tools under `mac/`; do not put normal Mac setup there.
