#!/usr/bin/env bash

# Terminal prompts used by installer domains and tools.

# Present a numbered list of options and return the selected index (0-based).
# Usage:
#   choice="$(ask_select "What do you want?" "Skip" "Option A" "Option B")"
#   case "$choice" in
#     0) echo "Skipped" ;;
#     1) echo "Chose A" ;;
#     2) echo "Chose B" ;;
#   esac
ask_select() {
  local question="$1"
  shift
  local options=("$@")
  local choice

  if ((${#options[@]} == 0)); then
    log_error 'ask_select: no options provided.'
    return 1
  fi

  printf '%s\n' "$question" >/dev/tty
  local i=0
  for option in "${options[@]}"; do
    printf '  %d) %s\n' "$i" "$option" >/dev/tty
    ((i += 1))
  done

  while true; do
    printf 'Choice (0-%d): ' "$((${#options[@]} - 1))" >/dev/tty
    read -r choice </dev/tty
    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 0 && choice < ${#options[@]})); then
      printf '%s\n' "$choice"
      return 0
    fi
    log_error "Invalid choice. Please enter a number between 0 and $((${#options[@]} - 1))."
  done
}

# Ask a yes/no question.
# Returns 0 for yes and 1 for no, so it can be used directly in an if statement.
# Usage:
#   if ask_binary "Continue?" "y"; then
#     echo "Continuing"
#   fi
ask_binary() {
  local question="$1"
  local default="${2:-y}"
  local answer
  local suffix

  if [[ "$default" == 'y' ]]; then
    suffix='Y/n'
  else
    suffix='y/N'
  fi

  while true; do
    printf '%s [%s]: ' "$question" "$suffix" >/dev/tty
    read -r answer </dev/tty
    answer="${answer:-$default}"

    case "$answer" in
      y | Y | yes | YES | Yes)
        return 0
        ;;
      n | N | no | NO | No)
        return 1
        ;;
    esac

    log_error 'Please answer yes or no.'
  done
}

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
