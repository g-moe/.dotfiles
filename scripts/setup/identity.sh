#!/usr/bin/env bash
set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$SETUP_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

valid_machine_name() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9-]{0,31}$ ]]
}

valid_machine_color() {
  case "$1" in
    blue | green | orange | purple | red | yellow | aqua | gray) ;;
    *) return 1 ;;
  esac
}

ask_machine_identity() {
  local color_choice default_name

  default_name="$(hostname -s | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9-' '-' |
    sed 's/^-//; s/-$//' | cut -c1-32)"
  while true; do
    MACHINE_NAME="$(read_value 'Machine name' "$default_name" | tr '[:upper:]' '[:lower:]')"
    valid_machine_name "$MACHINE_NAME" && break
    log 'Use 1-32 lowercase letters, numbers, or dashes.'
  done

  color_choice="$(choose 'Machine color:' Blue Green Orange Purple Red Yellow Aqua Gray)"
  case "$color_choice" in
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
    "$MACHINE_NAME" "$MACHINE_COLOR" >"$ROOT_DIR/machine.json"
}

load_machine_identity() {
  local config="$ROOT_DIR/machine.json"

  if [[ -f "$config" ]] && ! confirm 'Change the saved machine name and color?'; then
    MACHINE_NAME="$(awk -F'"' '$2 == "name" { print $4; exit }' "$config")"
    MACHINE_COLOR="$(awk -F'"' '$2 == "color" { print $4; exit }' "$config")"
    valid_machine_name "$MACHINE_NAME" || die "Bad machine name in $config"
    valid_machine_color "$MACHINE_COLOR" || die "Bad machine color in $config"
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
