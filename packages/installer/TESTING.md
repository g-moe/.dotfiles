# Installer tests

The test tree mirrors the installer tree. Run commands below from the repository
root at `~/.dotfiles`.

```text
packages/installer/tests/
├── install.sh       Installer flow
├── setup/<phase>/   Setup strategies
├── lib/             Installer libraries
└── repository/      Repository layout and installed links
```

`tests/run.sh` runs the local test suite. `verify:machine` runs
`tests/repository/installed-links.sh` separately.

## Edit or add a test

1. Find the test for the code you will change. Put strategy tests under
   `tests/setup/<phase>/`, library tests under `tests/lib/`, and repository
   checks under `tests/repository/`. Use `tests/install.sh` for installer flow.

2. Add a check for the required behavior. For a bug fix, run it before the fix
   and confirm that it fails for the expected reason. Check script text only
   when the text itself is the requirement, such as strategy registration.

3. Use `set -euo pipefail` in test scripts. Source `tests/lib/test.sh` through
   a path relative to the test file when you need shared paths, `fail`, or
   `expect_file_contains`. Follow the nearest existing test.

4. Keep runtime tests separate from the machine's real configuration. Create
   fixtures with `mktemp -d` and remove them with an `EXIT` trap. Pass a temporary
   `HOME` to commands that write user files. Replace external commands with
   test functions or executables on a temporary `PATH`. Check their arguments,
   outputs, and exit status. Cover first runs, repeat runs, and failure cases
   when the change affects them.

5. Add each new local test to the `tests` array in `tests/run.sh`. The runner
   does not discover tests automatically. Check that `.gitignore` permits the
   new file; `!/packages/installer/**` already permits installer test files.

6. Run the test you changed, then the full local suite. Fix failures in the
   code or test setup. Do not skip checks or change an assertion to accept
   incorrect behavior.

For runtime test examples, see
[Cursor CLI setup](tests/setup/development/cursor-cli.sh) for command replacements
and an isolated home, and [skill setup](tests/setup/agents/skills.sh) for file
changes and repeat runs. Shared Bash library details are in the
[Bash package README](../lib/bash/README.md).

## Run local checks

Use the path of the test you changed. For example:

```bash
bash -n packages/installer/tests/setup/development/cursor-cli.sh
bash packages/installer/tests/setup/development/cursor-cli.sh
npm run install:test
git diff --check
```

The runner executes each test in a separate Bash process and stops at the first
failure. Read the `FAIL:` message or error output, correct the cause, and run the
failed test again before the full suite.

Local tests check script structure and behavior with controlled inputs. They do
not establish that a real package installation or desktop change works.

## Check installed links

After a machine install, run:

```bash
npm run verify:machine
```

This command reads the installed configuration. It checks link targets and
broken links. It does not install files or run as part of the local suite.
