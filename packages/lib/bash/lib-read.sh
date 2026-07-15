#!/usr/bin/env bash

# Free-text and secret prompts. Sourced by lib.sh.

# Read one line of input and print the answer.
# If a default is provided and the user presses enter, print the default.
# Usage:
#   hostname="$(read_value "Hostname" "my-mac")"
read_value() {
  local question="$1"
  local default="${2:-}"
  local answer

  if [[ -n "$default" ]]; then
    printf '%s [%s]: ' "$question" "$default" >/dev/tty
  else
    printf '%s: ' "$question" >/dev/tty
  fi

  read -r answer </dev/tty
  printf '%s\n' "${answer:-$default}"
}

# Read a secret from the terminal without echoing input.
# Fails if the value is empty.
# Usage:
#   password="$(read_secret 'Remote Desktop password')"
read_secret() {
  local prompt="$1"
  local value

  printf '%s: ' "$prompt" >/dev/tty
  read -rs value </dev/tty
  printf '\n' >/dev/tty
  [[ -n "$value" ]] || die "$prompt cannot be empty."
  printf '%s\n' "$value"
}
