## Rules

**Always keep `.md` files up-to-date.** After all tasks are completed, ensure `.md` files are not stale. Docs should mostly be patch-only, instead of heavy adds.
**Whitelist new files in `.gitignore`.** The root `.gitignore` ignores everything by default (`*` on line 2). Any new file or directory that should be tracked must be explicitly whitelisted with a `!` pattern so it is not accidentally committed.

## Directory-Specific Rules

- [`packages/installer/AGENTS.md`](packages/installer/AGENTS.md) — Machine installer rules and testing requirements

## Package Boundaries

- The root `package.json` is the public command entry point. Keep the existing `install:*` and `verify:machine` command names; they must call `packages/installer/install.sh` or its tests.
- `packages/installer` may depend on every lower package because it installs and configures them. Nothing may depend on `packages/installer`.
- `packages/lib/bash` is standalone and has no package dependencies. Reusable Bash libraries and cross-platform Bash tools belong there; every package may use it.
- `packages/lib/ts` is standalone and has no package dependencies. Shared TypeScript belongs there; every package may use it. Keep its `.gitkeep` until shared TypeScript exists.
- `packages/mac`, `packages/theming`, and `packages/vscode-ext` may depend on `packages/lib/bash` or `packages/lib/ts`, never on `packages/installer`.
- Keep installer-only Bash helpers inside `packages/installer/lib`. Do not move package installation or OS validation into the shared Bash library.
- Mirror `packages/installer` paths under `packages/installer/tests` so each test lives with the area it checks.
