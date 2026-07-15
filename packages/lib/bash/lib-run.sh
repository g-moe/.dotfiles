#!/usr/bin/env bash

# Step labels, fatal exits, and error handling. Sourced by lib.sh (needs logging first).

# Print an error and exit the process.
# Usage: die 'Homebrew is missing.'
die() {
  log_error "$*"
  exit 1
}

# Run a labeled step, tracking CURRENT_STEP for the error trap.
# Usage: run_step 'Install Chrome' install_chrome
run_step() {
  local label="$1"
  local previous_step="${CURRENT_STEP:-}"
  shift

  CURRENT_STEP="$label"
  log_section "$label"
  "$@"
  CURRENT_STEP="$previous_step"
}

# ERR trap handler. Prints the failed step, command, and source location.
error_trap() {
  local status=$?
  local command="${BASH_COMMAND:-unknown}"
  local source="${BASH_SOURCE[1]:-}"
  local line="${BASH_LINENO[0]:-}"

  if [[ -n "${CURRENT_STEP:-}" ]]; then
    log_error "$CURRENT_STEP failed with exit code $status."
  else
    log_error "Command failed with exit code $status."
  fi

  log_error "Command: $command"
  if [[ -n "$source" && -n "$line" && "$line" != '0' ]]; then
    log_error "Location: $source:$line"
  fi
  exit "$status"
}

# Enable the shared ERR trap for the current shell.
# Usage: enable_error_trap
enable_error_trap() {
  set -E
  trap error_trap ERR
}
