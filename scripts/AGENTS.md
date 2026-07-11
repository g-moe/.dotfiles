# Scripts Directory — Agent Rules

This directory contains the shared macOS and Ubuntu installers plus Mac-only tools.

## Workflow

1. Keep this file up to date when script layout or conventions change.
2. Whitelist every new tracked file in the root `.gitignore`.
3. Run `npm run install:test` and syntax checks after installer changes.

## Structure

- `lib/` — Source-only Bash helpers. Library filenames start with `lib-`.
- `shared/install/` — Executable setup domains and the single shared Brewfile.
- `shared/tools/` — Shared commands used outside the main installer.
- `shared/tests/` — Dependency-free installer tests using fake commands.
- `mac/` — Mac-only install steps and tools. Runtime filenames start with `mac-`.
- `mac-install.sh` — Shared install followed by Mac-only software and settings.
- `linux-install.sh` — Shared install for Ubuntu 26.04 LTS; no Linux settings.
- Root `machine.json` — Ignored, machine-local name and color created by installers through `lib-machine-identity.sh`.

## Conventions

- Executable Bash scripts use `set -euo pipefail`; source-only libraries and Raycast wrappers that intentionally return success after handled UI errors are exceptions.
- General helpers stay in `scripts/lib`; scripts that install or configure a tool belong in `scripts/shared/install`.
- Source `lib/lib-logging.sh` for logging and `run_step`.
- Source `lib/lib-interactive.sh` for prompts.
- Source `lib/lib-machine-identity.sh` to create or reuse the shared machine name and color.
- Source `lib/lib-utils.sh` for command checks, silent commands, Homebrew checks, and `safe_link`.
- Source `lib/lib-runtime.sh` to reload Homebrew or NVM in a fresh process.
- Source `lib/lib-get-linux-or-mac.sh` for platform checks and `mac()`/`linux()` routing.
- Each shared setup domain runs in a fresh Bash process and sources its own helpers.
- Put OS-specific work in literal `mac()` and `linux()` functions. Do not use `eval` for routing.
- Use `safe_link SOURCE TARGET`: correct links are left alone, other links are replaced, and real files or directories are never overwritten.
- Install shared and OS-specific Homebrew entries through `shared/install/shared-Brewfile`. Do not run `brew bundle cleanup`.
- Node setup uses Node.js 24 through NVM; keep it aligned with `.nvmrc` and `package.json`.
- Ubuntu support is limited to Ubuntu 26.04 LTS on amd64 with SSSE3 or arm64.
