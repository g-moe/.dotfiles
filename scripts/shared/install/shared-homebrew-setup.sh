#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../../lib"

. "$LIB_DIR/lib-get-linux-or-mac.sh"
. "$LIB_DIR/lib-logging.sh"
. "$LIB_DIR/lib-runtime.sh"
. "$LIB_DIR/lib-utils.sh"

enable_install_error_trap

ensure_normal_user() {
  if [[ "$(id -u)" -eq 0 ]]; then
    log_error 'Do not run Homebrew setup with sudo.'
    return 1
  fi
}

ensure_ubuntu_26_04() {
  local ID=''
  local VERSION_ID=''

  if [[ ! -r /etc/os-release ]]; then
    log_error 'Cannot identify Linux: /etc/os-release is missing.'
    return 1
  fi

  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "$ID" != 'ubuntu' || "$VERSION_ID" != '26.04' ]]; then
    log_error "Linux setup supports Ubuntu 26.04 only; found ${ID:-unknown} ${VERSION_ID:-unknown}."
    return 1
  fi
}

ensure_supported_linux_cpu() {
  local architecture
  architecture="$(uname -m)"

  case "$architecture" in
    arm64 | aarch64)
      ;;
    x86_64 | amd64)
      if [[ ! -r /proc/cpuinfo ]] || ! grep -qw ssse3 /proc/cpuinfo; then
        log_error 'Homebrew on x86_64 requires a CPU with SSSE3 support.'
        return 1
      fi
      ;;
    *)
      log_error "Unsupported Linux CPU architecture: $architecture"
      return 1
      ;;
  esac
}

install_ubuntu_prerequisites() {
  if ! has_command sudo; then
    log_error 'sudo is required to install Ubuntu prerequisites.'
    return 1
  fi

  log_info 'Installing Ubuntu prerequisites for Homebrew...'
  sudo apt-get update
  sudo apt-get install -y \
    build-essential \
    procps \
    curl \
    file \
    git \
    ca-certificates
}

prepare_linuxbrew_parent() {
  sudo mkdir -p /home/linuxbrew
  sudo chmod 0755 /home/linuxbrew
}

install_homebrew() {
  if load_homebrew; then
    log_info 'Homebrew already installed.'
    return
  fi

  if ! has_command curl; then
    log_error 'curl is required to install Homebrew.'
    return 1
  fi

  log_info 'Installing Homebrew...'
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if ! load_homebrew; then
    log_error 'Homebrew installation finished, but brew is not available.'
    return 1
  fi
  log_info 'Homebrew installed.'
}

mac() {
  ensure_normal_user
  install_homebrew
}

linux() {
  ensure_ubuntu_26_04
  ensure_supported_linux_cpu
  ensure_normal_user
  prepare_linuxbrew_parent

  if ! load_homebrew; then
    install_ubuntu_prerequisites
  fi
  install_homebrew
}

main() {
  dispatch_linux_or_mac "$@"
}

main "$@"
