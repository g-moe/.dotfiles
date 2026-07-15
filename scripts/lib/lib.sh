#!/usr/bin/env bash

# Single entry point for shared script helpers. Source this file; do not source the focused libraries directly.
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$LIB_DIR/lib-logging.sh"
. "$LIB_DIR/lib-run.sh"
. "$LIB_DIR/lib-interactive.sh"
. "$LIB_DIR/lib-utils.sh"
. "$LIB_DIR/lib-packages.sh"
. "$LIB_DIR/lib-install.sh"

enable_error_trap
