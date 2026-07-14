#!/usr/bin/env bash

# One import for every setup file. The work lives in focused shared libraries.
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$LIB_DIR/lib-logging.sh"
. "$LIB_DIR/lib-interactive.sh"
. "$LIB_DIR/lib-utils.sh"
. "$LIB_DIR/lib-packages.sh"

detect_os() {
  case "$(uname -s)" in
    Darwin) OS=mac ;;
    Linux)
      OS=linux
      has dpkg || die 'Ubuntu package tools are missing.'
      LINUX_ARCH="$(dpkg --print-architecture)"
      case "$LINUX_ARCH" in
        amd64 | arm64) ;;
        *) die "Ubuntu amd64 or arm64 is required; found $LINUX_ARCH." ;;
      esac
      export LINUX_ARCH
      ;;
    *) die "Unsupported system: $(uname -s)" ;;
  esac
  export OS
}

validate_os() {
  local ID='' VERSION_ID=''

  case "$OS" in
    mac) ;;
    linux)
      [[ -r /etc/os-release ]] || die 'Ubuntu identification file is missing.'
      # shellcheck disable=SC1091
      . /etc/os-release
      [[ "$ID" == ubuntu && "$VERSION_ID" == 26.04 ]] ||
        die "Ubuntu 26.04 is required; found ${ID:-unknown} ${VERSION_ID:-unknown}."
      ;;
    *) die "Unsupported OS value: $OS" ;;
  esac
}

validate_user() {
  [[ "$(id -u)" -ne 0 ]] || die 'Run the installer as your normal user, not with sudo.'
  has sudo || die 'sudo is required.'
  sudo -v
}

machine_field() {
  local config="$1"
  local field="$2"
  local value

  value="$(awk -F'"' -v field="$field" '$2 == field { print $4; exit }' "$config")"
  [[ -n "$value" ]] || die "Missing $field in $config"
  printf '%s\n' "$value"
}

machine_color_values() {
  case "$1" in
    blue) printf '#458588|0.270588 0.521569 0.533333 0.250000\n' ;;
    green) printf '#B8BB26|0.721569 0.733333 0.149020 0.250000\n' ;;
    orange) printf '#FE8019|0.996078 0.501961 0.098039 0.250000\n' ;;
    purple) printf '#D3869B|0.827451 0.525490 0.607843 0.250000\n' ;;
    red) printf '#FB4934|0.984314 0.286275 0.203922 0.250000\n' ;;
    yellow) printf '#FABD2F|0.980392 0.741176 0.184314 0.250000\n' ;;
    aqua) printf '#8EC07C|0.556863 0.752941 0.486275 0.250000\n' ;;
    gray) printf '#A89984|0.658824 0.600000 0.517647 0.250000\n' ;;
    *) die "Unknown machine color: $1" ;;
  esac
}

machine_color_hex() {
  local values
  values="$(machine_color_values "$1")"
  printf '%s\n' "${values%%|*}"
}

machine_color_tint() {
  local values
  values="$(machine_color_values "$1")"
  printf '%s\n' "${values#*|}"
}
