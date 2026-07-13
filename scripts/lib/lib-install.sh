#!/usr/bin/env bash

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '%s\n' "$*"
}

section() {
  printf '\n==> %s\n' "$*"
}

run_step() {
  local label="$1"
  shift
  section "$label"
  "$@"
}

has() {
  command -v "$1" >/dev/null 2>&1
}

link_config() {
  local source="$1"
  local target="$2"

  [[ "$source" == "$target" ]] && return
  mkdir -p "$(dirname "$target")"
  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    return
  fi
  [[ ! -e "$target" && ! -L "$target" ]] || die "Refusing to replace $target"
  ln -s "$source" "$target"
}

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

read_value() {
  local prompt="$1"
  local default_value="${2:-}"
  local value

  if [[ -n "$default_value" ]]; then
    printf '%s [%s]: ' "$prompt" "$default_value" >/dev/tty
  else
    printf '%s: ' "$prompt" >/dev/tty
  fi
  read -r value </dev/tty
  printf '%s\n' "${value:-$default_value}"
}

read_secret() {
  local prompt="$1"
  local value

  printf '%s: ' "$prompt" >/dev/tty
  read -rs value </dev/tty
  printf '\n' >/dev/tty
  [[ -n "$value" ]] || die "$prompt cannot be empty."
  printf '%s\n' "$value"
}

choose() {
  local prompt="$1"
  shift
  local choice index

  printf '%s\n' "$prompt" >/dev/tty
  index=0
  for choice in "$@"; do
    printf '  %d) %s\n' "$index" "$choice" >/dev/tty
    index=$((index + 1))
  done

  while true; do
    printf 'Choice (0-%d): ' "$(($# - 1))" >/dev/tty
    read -r choice </dev/tty
    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 0 && choice < $#)); then
      printf '%s\n' "$choice"
      return
    fi
  done
}

confirm() {
  local prompt="$1"
  local choice
  choice="$(choose "$prompt" 'No' 'Yes')"
  [[ "$choice" == 1 ]]
}

install_root_file() {
  local path="$1"
  local content="$2"
  local temporary_file

  temporary_file="$(mktemp)"
  printf '%s\n' "$content" >"$temporary_file"
  sudo install -D -m 0644 "$temporary_file" "$path"
  rm -f "$temporary_file"
}

install_apt_key() {
  local url="$1"
  local path="$2"
  local format="${3:-plain}"
  local fingerprint="${4:-}"
  local actual raw_file output_file

  raw_file="$(mktemp)"
  output_file="$(mktemp)"
  curl -fsSL "$url" -o "$raw_file"

  if [[ -n "$fingerprint" ]]; then
    actual="$(gpg --batch --quiet --show-keys --with-colons "$raw_file" |
      awk -F: '$1 == "fpr" { print $10; exit }')"
    [[ "$actual" == "$fingerprint" ]] || die "Signing key did not match for $url"
  fi

  case "$format" in
    plain) cp "$raw_file" "$output_file" ;;
    dearmor) gpg --batch --yes --dearmor --output "$output_file" "$raw_file" ;;
    *) die "Unknown key format: $format" ;;
  esac

  sudo install -D -m 0644 "$output_file" "$path"
  rm -f "$raw_file" "$output_file"
}

download_github_asset() {
  local repository="$1"
  local pattern="$2"
  local suffix="$3"
  local asset digest file metadata url

  metadata="$(curl -fsSL "https://api.github.com/repos/$repository/releases/latest" |
    jq -r --arg pattern "$pattern" \
      '.assets[] | select(.name | test($pattern; "i")) | [.browser_download_url, .digest] | @tsv' |
    head -n 1)"
  IFS=$'\t' read -r url digest <<<"$metadata"
  [[ -n "$url" && "$url" != null ]] || die "No $repository release matched $pattern"
  [[ "$digest" == sha256:* ]] || die "No checksum was published for $url"

  file="$(mktemp --suffix="$suffix")"
  curl -fL "$url" -o "$file"
  printf '%s  %s\n' "${digest#sha256:}" "$file" | sha256sum --check --status ||
    die "Checksum failed for $url"
  printf '%s\n' "$file"
}

load_homebrew() {
  local brew_bin=''

  export HOMEBREW_NO_ASK=1
  if has brew; then
    return
  fi
  case "$(uname -m)" in
    arm64) brew_bin=/opt/homebrew/bin/brew ;;
    x86_64) brew_bin=/usr/local/bin/brew ;;
    *) die "Unsupported Mac architecture: $(uname -m)" ;;
  esac
  [[ -x "$brew_bin" ]] || return 1
  eval "$("$brew_bin" shellenv)"
}

install_homebrew() {
  if load_homebrew; then
    return
  fi
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  load_homebrew || die 'Homebrew did not become available.'
}

brew_formula() {
  load_homebrew || die 'Homebrew is not installed.'
  brew install --no-ask --formula "$@"
}

brew_cask() {
  load_homebrew || die 'Homebrew is not installed.'
  brew install --no-ask --cask "$@"
}

apt_install() {
  sudo apt-get install -y "$@"
}

enable_gnome_extension() {
  local uuid="$1"
  local enabled

  enabled="$(gsettings get org.gnome.shell enabled-extensions)"
  if [[ "$enabled" != *"'$uuid'"* ]]; then
    case "$enabled" in
      '[]' | '@as []') enabled="['$uuid']" ;;
      *) enabled="${enabled%]}, '$uuid']" ;;
    esac
    gsettings set org.gnome.shell enabled-extensions "$enabled"
  fi
  gnome-extensions enable "$uuid" >/dev/null 2>&1 || true
}

unsupported_os() {
  die "Unsupported OS value: $OS"
}

machine_field() {
  local config="$1"
  local field="$2"
  local value

  value="$(awk -F'"' -v field="$field" '$2 == field { print $4; exit }' "$config")"
  [[ -n "$value" ]] || die "Missing $field in $config"
  printf '%s\n' "$value"
}

machine_color_hex() {
  case "$1" in
    blue) printf '#458588\n' ;;
    green) printf '#B8BB26\n' ;;
    orange) printf '#FE8019\n' ;;
    purple) printf '#D3869B\n' ;;
    red) printf '#FB4934\n' ;;
    yellow) printf '#FABD2F\n' ;;
    aqua) printf '#8EC07C\n' ;;
    gray) printf '#A89984\n' ;;
    *) die "Unknown machine color: $1" ;;
  esac
}

machine_color_tint() {
  case "$1" in
    blue) printf '0.270588 0.521569 0.533333 0.250000\n' ;;
    green) printf '0.721569 0.733333 0.149020 0.250000\n' ;;
    orange) printf '0.996078 0.501961 0.098039 0.250000\n' ;;
    purple) printf '0.827451 0.525490 0.607843 0.250000\n' ;;
    red) printf '0.984314 0.286275 0.203922 0.250000\n' ;;
    yellow) printf '0.980392 0.741176 0.184314 0.250000\n' ;;
    aqua) printf '0.556863 0.752941 0.486275 0.250000\n' ;;
    gray) printf '0.658824 0.600000 0.517647 0.250000\n' ;;
    *) die "Unknown machine color: $1" ;;
  esac
}
