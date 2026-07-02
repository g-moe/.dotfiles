#!/usr/bin/env bash

# Present a numbered list of options and return the selected index (0-based).
# Usage:
#   choice="$(interactive_select "What do you want?" "Skip" "Option A" "Option B")"
#   case "$choice" in
#     0) echo "Skipped" ;;
#     1) echo "Chose A" ;;
#     2) echo "Chose B" ;;
#   esac
interactive_select() {
  local question="$1"
  shift
  local options=("$@")
  local choice

  if ((${#options[@]} == 0)); then
    log_error 'interactive_select: no options provided.'
    return 1
  fi

  printf '%s\n' "$question" >/dev/tty
  local i=0
  for option in "${options[@]}"; do
    printf '  %d) %s\n' "$i" "$option" >/dev/tty
    ((i += 1))
  done

  while true; do
    printf 'Enter choice (0-%d): ' "$((${#options[@]} - 1))" >/dev/tty
    read -r choice </dev/tty
    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 0 && choice < ${#options[@]})); then
      printf '%s\n' "$choice"
      return 0
    fi
    log_error "Invalid choice. Please enter a number between 0 and $((${#options[@]} - 1))."
  done
}
