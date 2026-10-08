# Shared Bash package

This package contains reusable Bash helpers and standalone tools for Mac and
Linux. It has no dependency on another repository package. Any package can use
it. Machine installation and OS validation belong in `packages/installer/lib/`.

## Layout

```text
packages/lib/bash/
├── lib.sh           Shared entry point
├── lib-logging.sh   Status and error output
├── lib-run.sh       Named steps and error handling
├── lib-ask.sh       Choice and yes/no input
├── lib-read.sh      Text and secret input
├── lib-utils.sh     Command checks, retries, and safe links
├── lib-retire.sh    Package retirement data validation
└── bin/             Standalone tools
```

Read the function comments in each file for arguments and examples. Keep shared
helpers in the library files and executable tools in `bin/`. Keep Mac-only
tools in `packages/mac/`.

## Entry points

Source `lib.sh` through a path relative to the calling script. Do not source the
individual library files. The entry point loads them in order and enables the
error trap in the current shell. Scripts set `set -euo pipefail` themselves.

Installer scripts source `packages/installer/lib/lib.sh` instead. It loads this
package first, then the installer libraries:

```text
Installer script
└── packages/installer/lib/lib.sh
    ├── packages/lib/bash/lib.sh   Shared helpers
    ├── lib-packages.sh            Downloads and package installation
    └── lib-install.sh             OS, machine, and Xfce setup
```

Other packages must not source the installer entry point. See the
[installer README](../../installer/README.md) for its script structure.

## Shared behavior

The error trap reports the exit status, command, source location, and current
step when available. `run_step` sets the step label. `die` reports an error and
exits the process.

Input helpers use `/dev/tty` so a script can capture their output. Choice and
text helpers print their result to stdout. Choice indices start at zero.
Yes/no input returns status 0 for yes and 1 for no. Use labels that match the
operation; Skip / Disable / Enable applies only to those three actions.

Safe link helpers preserve real directories and links that already match.
Existing files and other links can be skipped or replaced. A link group checks
all source paths before creating links and asks once for existing items. Skip
preserves those items and still creates missing links.

`bin/` tools run as separate processes. Read each tool for its inputs and
external command requirements. Retirement data validation requires `jq`.

## Checks

Run `npm run install:test` from the repository root. The current shared-library
checks live in [the installer test tree](../../installer/tests/lib/).
