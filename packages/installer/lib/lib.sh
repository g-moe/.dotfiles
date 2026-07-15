#!/usr/bin/env bash

# Installer helper entry point. Load the standalone Bash library first, then
# installer-only package and operating-system helpers.
INSTALLER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASH_LIB_DIR="$(cd "$INSTALLER_LIB_DIR/../../lib/bash" && pwd)"
. "$BASH_LIB_DIR/lib.sh"
. "$INSTALLER_LIB_DIR/lib-packages.sh"
. "$INSTALLER_LIB_DIR/lib-install.sh"
