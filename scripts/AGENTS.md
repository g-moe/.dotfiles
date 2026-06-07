# Scripts Directory — Agent Rules

This directory contains installation and configuration scripts for macOS.

## Workflow

1. **Always keep this file up-to-date.** If you add new scripts, helpers, or conventions, document them here.
2. **Use `scripts/lib/utils.sh` for silent output.** The `silent()` helper wraps commands to suppress stdout/stderr. Prefer `silent some_command || true` over `some_command >/dev/null 2>&1 || true`.
3. **Whitelist new files in `.gitignore`.** The root `.gitignore` ignores everything by default (`*` on line 2). Any new file or directory that should be tracked must be explicitly whitelisted with a `!` pattern so it is not accidentally committed.

## Structure

- `lib/` — Shared shell helpers (`logging.sh`, `interactive.sh`, `utils.sh`)
- `mac-only/` — macOS-specific utilities and tools not used during install
- `mac-only/install/` — Install-time scripts called by `mac-install.sh`
  - `mac-install-software.sh`, `mac-system-settings.sh`, `mac-power-mode.ts`, `mac-file-associations.sh`, `setup-file-associations.sh`, `finder-sidebar.js`
- `mac-install.sh` — Main macOS setup entrypoint
  - Includes an interactive power mode step (`Normal` or `Server`) applied via `mac-only/install/mac-power-mode.ts`
- `mac-uninstall.sh` — macOS teardown

## Conventions

- All scripts use `set -euo pipefail`
- Source `lib/logging.sh` for `log_info`, `log_error`, `log_section`, `run_step`
- Source `lib/interactive.sh` for `interactive_select` (0-based options, Skip is always option 0)
- Source `lib/utils.sh` for `silent()`, `has_command()`, `brew_has_cask()`, `brew_has_formula()`
- `run_step` wraps every major configuration phase so the installer prints clear `==> Step Name` headers
- Node setup installs and uses Node.js 24 LTS via `nvm`; keep this aligned with the root `.nvmrc` and package `engines`.
