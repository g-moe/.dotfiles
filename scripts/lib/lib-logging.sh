#!/usr/bin/env bash

# Shared logging helpers.

# Print a normal status line.
# Usage: log 'Homebrew is ready.'
log() {
  printf '%s\n' "$*"
}

# Print a section banner.
# Usage: log_section 'Installing apps'
log_section() {
  printf '\n==> %s\n' "$*"
}

# Print an error to stderr.
# Usage: log_error 'Homebrew is missing.'
log_error() {
  printf 'ERROR: %s\n' "$*" >&2
}
