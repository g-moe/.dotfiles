## Rules

**Always keep `.md` files up-to-date.** After all tasks are completed, ensure `.md` files are not stale because of your actions.
**Whitelist new files in `.gitignore`.** The root `.gitignore` ignores everything by default (`*` on line 2). Any new file or directory that should be tracked must be explicitly whitelisted with a `!` pattern so it is not accidentally committed.
**Use disposable UTM clones for VM tests.** When asked to test with a VM, clone the clean UTM VM first and run the test only in that clone. Never change the reusable base VM during a test.

## Directory-Specific Rules

- [`scripts/AGENTS.md`](scripts/AGENTS.md) — macOS and Ubuntu installers, shared shell helpers, and conventions
