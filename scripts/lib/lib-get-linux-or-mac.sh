#!/usr/bin/env bash

# Print the kernel family used by installer domains.
get_linux_or_mac() {
  local kernel
  kernel="$(uname -s)"

  case "$kernel" in
    Darwin)
      printf '%s\n' 'mac'
      ;;
    Linux)
      printf '%s\n' 'linux'
      ;;
    *)
      printf 'ERROR: Unsupported operating system: %s\n' "$kernel" >&2
      return 1
      ;;
  esac
}

# Require the current kernel family to match mac or linux.
require_linux_or_mac() {
  local expected="$1"
  local actual

  case "$expected" in
    mac | linux) ;;
    *)
      printf 'ERROR: Expected machine type must be mac or linux; received %s.\n' \
        "$expected" >&2
      return 1
      ;;
  esac

  actual="$(get_linux_or_mac)" || return
  if [[ "$actual" != "$expected" ]]; then
    printf 'ERROR: This command requires %s; found %s.\n' "$expected" "$actual" >&2
    return 1
  fi
}

# Call the mac() or linux() function declared by a fresh-process domain.
dispatch_linux_or_mac() {
  local machine_type
  machine_type="$(get_linux_or_mac)" || return

  case "$machine_type" in
    mac)
      if ! declare -F mac >/dev/null 2>&1; then
        printf 'ERROR: Missing mac() implementation in %s.\n' \
          "${BASH_SOURCE[1]:-$0}" >&2
        return 1
      fi
      mac "$@"
      ;;
    linux)
      if ! declare -F linux >/dev/null 2>&1; then
        printf 'ERROR: Missing linux() implementation in %s.\n' \
          "${BASH_SOURCE[1]:-$0}" >&2
        return 1
      fi
      linux "$@"
      ;;
  esac
}
