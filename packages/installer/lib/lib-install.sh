#!/usr/bin/env bash

# Operating-system and machine helpers. Sourced by lib.sh.

# Detect mac or linux and export OS. On Linux also export LINUX_ARCH.
# Usage: detect_os
detect_os() {
  case "$(uname -s)" in
    Darwin) OS=mac ;;
    Linux)
      OS=linux
      has dpkg || die 'Debian package tools are missing.'
      LINUX_ARCH="$(dpkg --print-architecture)"
      case "$LINUX_ARCH" in
        amd64 | arm64) ;;
        *) die "Debian amd64 or arm64 is required; found $LINUX_ARCH." ;;
      esac
      export LINUX_ARCH
      ;;
    *) die "Unsupported system: $(uname -s)" ;;
  esac
  export OS
}

# Require a supported OS after detect_os.
# Usage: validate_os
validate_os() {
  local ID='' VERSION_CODENAME='' VERSION_ID=''

  case "$OS" in
    mac) ;;
    linux)
      [[ -r /etc/os-release ]] || die 'Debian identification file is missing.'
      # shellcheck disable=SC1091
      . /etc/os-release
      [[ "$ID" == debian && "$VERSION_ID" == 13 && "$VERSION_CODENAME" == trixie ]] ||
        die "Debian 13 (trixie) is required; found ${ID:-unknown} ${VERSION_ID:-unknown} (${VERSION_CODENAME:-unknown})."
      LINUX_CODENAME="$VERSION_CODENAME"
      export LINUX_CODENAME
      ;;
    *) die "Unsupported OS value: $OS" ;;
  esac
}

# Require a normal user with working sudo, not root.
# Usage: validate_user
validate_user() {
  [[ "$(id -u)" -ne 0 ]] || die 'Run the installer as your normal user, not with sudo.'
  has sudo || die 'sudo is required.'
  sudo -v
}

# Load NVM without selecting a Node version.
# Usage: load_nvm
load_nvm() {
  export NVM_DIR="$HOME/.nvm"
  [[ -s "$NVM_DIR/nvm.sh" ]] || return 1
  set +u
  # shellcheck disable=SC1090
  . "$NVM_DIR/nvm.sh" --no-use
  set -u
}

# Select the repo's pinned Node version when Node is not already available in
# the current shell.
# Usage: activate_repo_node "$ROOT_DIR"
activate_repo_node() {
  local root="$1"
  local version

  has npx && return 0
  load_nvm || return 1
  set +u
  version="$(tr -d '[:space:]' <"$root/.nvmrc")"
  nvm use "$version" >/dev/null
  set -u
  has npx
}

# Read a string field from machine.json.
# Usage: name="$(machine_field "$ROOT_DIR/machine.json" name)"
machine_field() {
  local config="$1"
  local field="$2"
  local value

  value="$(awk -F'"' -v field="$field" '$2 == field { print $4; exit }' "$config")"
  [[ -n "$value" ]] || die "Missing $field in $config"
  printf '%s\n' "$value"
}

# Print "hex|tint" for a machine color name.
# Usage: values="$(machine_color_values blue)"
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
    black) printf '#101010|0.062745 0.062745 0.062745 0.250000\n' ;;
    *) die "Unknown machine color: $1" ;;
  esac
}

# Print the hex color for a machine color name.
# Usage: hex="$(machine_color_hex blue)"
machine_color_hex() {
  local values
  values="$(machine_color_values "$1")"
  printf '%s\n' "${values%%|*}"
}

# Print the tint components for a machine color name.
# Usage: tint="$(machine_color_tint blue)"
machine_color_tint() {
  local values
  values="$(machine_color_values "$1")"
  printf '%s\n' "${values#*|}"
}

# Render the shared machine-color artwork at one size.
# Usage: render_machine_background "$source" "$color_hex" 6016x3388 "$output"
render_machine_background() {
  local source="$1"
  local color_hex="$2"
  local output_size="$3"
  local output="$4"
  local temporary_dir temporary_path

  mkdir -p "$(dirname "$output")"
  temporary_dir="$(mktemp -d "$(dirname "$output")/.machine-background.XXXXXX")"
  temporary_path="$temporary_dir/background.png"
  if ! magick "$source" \
    -rotate 180 \
    -colorspace gray \
    +level-colors '#000000',"$color_hex" \
    -resize "$output_size!" \
    \( -size 1504x847 radial-gradient:white-black +level '25%,100%' -resize "$output_size!" \) \
    -compose multiply \
    -composite \
    "$temporary_path"; then
    rm -rf "$temporary_dir"
    die 'Could not create the machine background.'
  fi
  if [[ ! -s "$temporary_path" ]]; then
    rm -rf "$temporary_dir"
    die 'Machine background image is empty.'
  fi
  mv "$temporary_path" "$output"
  rm -rf "$temporary_dir"
}

# Set one Xfce value, creating it when the property does not exist yet.
# Usage: xfconf_set xsettings /Net/ThemeName string WhiteSur-Dark
xfconf_set() {
  local channel="$1"
  local property="$2"
  local type="$3"
  local value="$4"

  if silent xfconf-query -c "$channel" -p "$property"; then
    xfconf-query -c "$channel" -p "$property" -s "$value"
  else
    xfconf-query -c "$channel" -p "$property" -n -t "$type" -s "$value"
  fi
}

# Replace one Xfce array. Remaining arguments are values of the same type.
# Usage: xfconf_set_array xfce4-panel /panels int 1
xfconf_set_array() {
  local channel="$1"
  local property="$2"
  local type="$3"
  local value
  local -a arguments=(-a)
  shift 3

  (($#)) || die "No values were provided for $channel $property"
  if ! silent xfconf-query -c "$channel" -p "$property"; then
    arguments=(-n -a)
  fi
  for value in "$@"; do
    arguments+=(-t "$type" -s "$value")
  done
  xfconf-query -c "$channel" -p "$property" "${arguments[@]}"
}
