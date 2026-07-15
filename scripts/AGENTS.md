# scripts/ — for agents

How to edit this tree. What the installer _is_ → [README.md](README.md). How to VM-test → [TESTING.md](TESTING.md).

# DO

- Keep these docs current; whitelist new tracked paths in the root `.gitignore`.
- Source only `lib/lib.sh`. Put new helpers in the matching `lib/lib-*.sh`.
- Prefer existing helpers (`die`, `has`, `log`, `silent`, `ask_choice`, `ask_binary`, …) over new locals.
- Use `silent` to suppress both streams; Bash with `set -euo pipefail`.
- One feature per `setup/` file, registered once in `install.sh`; match neighbor shape (`mac` / `linux`, `"$1"`).
- Cross-OS tools → `shared/shared-*.sh`. Mac-only tools → `mac/mac-*.sh`. Linux-only tools → `linux/linux-*.sh`
- `return 0` on skips; use `$LINUX_ARCH`; comment _why_.
- Skip/Enable/Disable only when those labels fit (`0` / `1` / `2`).
- Clean machines only. `npm run install:test` after shape/lib edits. VM tests only in disposable UTM clones.

# DONT

- Source focused libs directly, or reinvent helpers that already exist.
- Use raw `>/dev/null 2>&1` when `silent` fits.
- Park installer strategies in `mac/` or `shared/`, or dump scripts at `scripts/` root.
- Reshape unrelated menus into Skip/Enable/Disable.
- Add migrations / old-path cleanup / backwards-compat branches.
- Touch a reusable base VM.
