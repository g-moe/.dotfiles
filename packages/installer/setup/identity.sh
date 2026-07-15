#!/usr/bin/env bash
set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$SETUP_DIR/.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

valid_machine_name() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9-]{0,31}$ ]]
}

ask_machine_identity() {
  local color_choice default_name
  local -a colors=(blue green orange purple red yellow aqua gray)

  default_name="$(hostname -s | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9-' '-' |
    sed 's/^-//; s/-$//' | cut -c1-32)"
  while true; do
    MACHINE_NAME="$(read_value 'Machine name' "$default_name" | tr '[:upper:]' '[:lower:]')"
    valid_machine_name "$MACHINE_NAME" && break
    log 'Use 1-32 lowercase letters, numbers, or dashes.'
  done

  color_choice="$(ask_choice 'Machine color:' "${colors[@]}")"
  MACHINE_COLOR="${colors[$color_choice]}"

  umask 077
  printf '{\n  "name": "%s",\n  "color": "%s"\n}\n' \
    "$MACHINE_NAME" "$MACHINE_COLOR" >"$ROOT_DIR/machine.json"
}

load_machine_identity() {
  local config="$ROOT_DIR/machine.json"

  if [[ -f "$config" ]] && ! ask_binary 'Change the saved machine name and color?'; then
    MACHINE_NAME="$(machine_field "$config" name)"
    MACHINE_COLOR="$(machine_field "$config" color)"
    valid_machine_name "$MACHINE_NAME" || die "Bad machine name in $config"
    machine_color_values "$MACHINE_COLOR" >/dev/null
  else
    ask_machine_identity
  fi
  export MACHINE_NAME MACHINE_COLOR
}

configure_identity() {
  load_machine_identity
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  sudo scutil --set ComputerName "$MACHINE_NAME"
  sudo scutil --set LocalHostName "$MACHINE_NAME"
  sudo scutil --set HostName "$MACHINE_NAME"
}

linux() {
  sudo hostnamectl set-hostname "$MACHINE_NAME"
}

configure_identity "$1"
