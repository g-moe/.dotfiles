#!/usr/bin/env bash

log_section() {
  printf '\n==> %s\n' "$1"
}

log_info() {
  printf ' - %s\n' "$1"
}

log_error() {
  printf 'ERROR: %s\n' "$1" >&2
}

install_error_trap() {
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

set -E
trap install_error_trap ERR

run_step() {
  local label="$1"
  local previous_step="${CURRENT_STEP:-}"
  shift

  CURRENT_STEP="$label"
  log_section "$label"
  "$@"
  CURRENT_STEP="$previous_step"
}
