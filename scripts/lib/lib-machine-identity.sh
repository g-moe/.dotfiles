#!/usr/bin/env bash

# Machine-local name and color shared by OS installers.
# Requires lib-interactive.sh and lib-logging.sh.

valid_machine_name() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9-]{0,31}$ ]]
}

valid_machine_color() {
  case "$1" in
    aqua | blue | green | orange | pink | purple | red | yellow | gray) return 0 ;;
    *) return 1 ;;
  esac
}

machine_config_value() {
  local key="$1"
  local config_path="$2"
  awk -F'"' -v key="$key" '$2 == key { print $4; exit }' "$config_path"
}

read_machine_config() {
  local config_path="$1"
  MACHINE_NAME="$(machine_config_value name "$config_path")"
  MACHINE_COLOR="$(machine_config_value color "$config_path")"

  if ! valid_machine_name "$MACHINE_NAME" || ! valid_machine_color "$MACHINE_COLOR"; then
    log_error "Invalid machine config: $config_path"
    log_error 'Delete it and rerun the installer to answer the machine questions again.'
    return 1
  fi
}

create_machine_config() {
  local config_path="$1"
  local choice default_name

  default_name="$(hostname -s | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9-' '-' | sed 's/^-//; s/-$//' | cut -c1-32)"
  while true; do
    MACHINE_NAME="$(interactive_read 'Machine name' "$default_name")"
    MACHINE_NAME="$(printf '%s' "$MACHINE_NAME" | tr '[:upper:]' '[:lower:]')"
    if valid_machine_name "$MACHINE_NAME"; then
      break
    fi
    log_error 'Use 1-32 lowercase letters, numbers, or dashes; start with a letter or number.'
  done

  choice="$(interactive_select 'Machine color:' 'Blue' 'Green' 'Orange' 'Purple' 'Red' 'Yellow' 'Aqua' 'Gray')"
  case "$choice" in
    0) MACHINE_COLOR=blue ;;
    1) MACHINE_COLOR=green ;;
    2) MACHINE_COLOR=orange ;;
    3) MACHINE_COLOR=purple ;;
    4) MACHINE_COLOR=red ;;
    5) MACHINE_COLOR=yellow ;;
    6) MACHINE_COLOR=aqua ;;
    7) MACHINE_COLOR=gray ;;
  esac

  umask 077
  printf '{\n  "name": "%s",\n  "color": "%s"\n}\n' \
    "$MACHINE_NAME" "$MACHINE_COLOR" >"$config_path"
  log_info "Saved machine config: $config_path"
}

configure_machine_identity() {
  local config_path="$1"

  if [[ -f "$config_path" ]]; then
    if interactive_confirm 'Change the saved machine name and color?' 'n'; then
      create_machine_config "$config_path"
    else
      read_machine_config "$config_path"
    fi
  else
    create_machine_config "$config_path"
  fi

  export MACHINE_NAME MACHINE_COLOR
  log_info "Machine: $MACHINE_NAME ($MACHINE_COLOR)"
}
