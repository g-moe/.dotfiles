# run-it

Repeat a quoted shell command and stop at its first failure.
Run `run-it`, `run-it --help`, or `run-it -h` to see options and examples.

```sh
run-it "pnpm run tests --force" --runs=10 --cpu=2 --mem=8
```

`--runs` is required. All values must be positive integers. Omit `--cpu` or
`--mem` to leave that resource unrestricted by this tool.

CPU limits select CPUs from the process's allowed affinity list using `taskset`,
skipping CPUs already pinned by another running `run-it`. If not enough CPUs are
free, `run-it` exits instead of sharing them.
Memory limits use `systemd-run --user --scope`, shared across the command and
its children, with swap disabled. Memory values use systemd's G unit (GiB).
Both limit options require Linux; unrestricted runs also work on macOS.
Commands run in `$SHELL` (falling back to `/bin/sh`) with the current directory
and environment. Interactive aliases and shell functions are not loaded.

Each invocation creates a unique temporary log directory and prints its path.
Failures print the last 100 log lines, the full log path, and return the command's
exit code. Logs remain available after completion.

Install from the dotfiles root with `npm run install:run-it`. The installer builds
TypeScript and links `dist/cli/main.js` into `~/.local/bin/run-it`. Development
setup installs it too. Existing shells that loaded the old function need
`unfunction run-it` once, or a fresh shell.

Validation: `npm run test:run-it` and
`npx tsc -b packages/run-it/tsconfig.test.json --noEmit`.
