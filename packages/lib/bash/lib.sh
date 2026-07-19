#!/usr/bin/env bash

# Single entry point for shared script helpers. Source this file; do not source the
# focused libraries directly.
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$LIB_DIR/lib-logging.sh"
. "$LIB_DIR/lib-run.sh"
. "$LIB_DIR/lib-ask.sh"
. "$LIB_DIR/lib-read.sh"
. "$LIB_DIR/lib-utils.sh"
. "$LIB_DIR/lib-retire.sh"

enable_error_trap
