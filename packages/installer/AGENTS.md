# packages/installer — for agents

How to edit this tree. What the installer _is_ → [README.md](README.md). How to VM-test → [TESTING.md](TESTING.md).

# DO

- Route **all** machine install through `packages/installer/install.sh` (flags like `--git`, `--skills`, `--theme`, `--apps`, or no arg for full). npm `install:git` / `install:skills` / `install:theme` / `install:machine` must call that file.
- Keep these docs current; whitelist new tracked paths in the root `.gitignore`.
- Source only `lib/lib.sh` from installer code. It loads `packages/lib/bash/lib.sh` before the installer-only libraries.
- Put reusable Bash helpers and cross-platform Bash tools in `packages/lib/bash`. Keep package installation and OS validation in this package's `lib/`.
- Prefer existing helpers (`die`, `has`, `log`, `silent`, `ask_choice`, `ask_binary`, …) over new locals.
- Use `silent` to suppress both streams; Bash with `set -euo pipefail`.
- One feature per `setup/` file, registered once in `install.sh`; match neighbor shape (`mac` / `linux`, `"$1"`).
- Cross-OS tools → `packages/lib/bash/bin/`. Mac-only tools → `packages/mac/`. Do not park standalone tools in the installer.
- `return 0` on skips; use `$LINUX_ARCH`; comment _why_.
- Skip/Disable/Enable only when those labels fit (`0` / `1` / `2`).
- Clean machines only. `npm run install:test` after shape/lib edits. VM tests only in disposable UTM clones.

# DONT

- Invoke `packages/installer/setup/**` directly (`bash packages/installer/setup/…`, npm scripts that point at setup files, or `detect_os` inside a strategy so it can run standalone).
- Source focused libs directly, or reinvent helpers that already exist.
- Use raw `>/dev/null 2>&1` when `silent` fits.
- Put standalone tools or unrelated app code in `packages/installer`, or dump scripts at the installer root.
- Reshape unrelated menus into Skip/Disable/Enable.
- Add migrations / old-path cleanup / backwards-compat branches.
- Touch a reusable base VM.
