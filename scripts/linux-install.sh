#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
SHARED_INSTALL_DIR="$SCRIPT_DIR/shared/install"

. "$LIB_DIR/lib-logging.sh"
. "$LIB_DIR/lib-interactive.sh"
. "$LIB_DIR/lib-machine-identity.sh"
. "$LIB_DIR/lib-utils.sh"
. "$LIB_DIR/lib-get-linux-or-mac.sh"

enable_install_error_trap

ensure_supported_linux() {
  local ID=''
  local VERSION_ID=''
  local architecture

  if [[ "$(uname -s)" != 'Linux' ]]; then
    log_error 'This installer only supports Linux.'
    return 1
  fi

  if [[ ! -r /etc/os-release ]]; then
    log_error 'Cannot identify Linux: /etc/os-release is missing.'
    return 1
  fi

  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "$ID" != 'ubuntu' || "$VERSION_ID" != '26.04' ]]; then
    log_error "This installer only supports Ubuntu 26.04 (found ${ID:-unknown} ${VERSION_ID:-unknown})."
    return 1
  fi

  architecture="$(uname -m)"
  case "$architecture" in
    aarch64 | arm64)
      ;;
    x86_64 | amd64)
      if [[ ! -r /proc/cpuinfo ]] || ! grep -qw ssse3 /proc/cpuinfo; then
        log_error 'This x86_64 CPU does not support SSSE3, which Homebrew requires.'
        return 1
      fi
      ;;
    *)
      log_error "Unsupported CPU architecture: $architecture"
      return 1
      ;;
  esac
}

ensure_normal_user() {
  if [[ "$(id -u)" -eq 0 ]]; then
    log_error 'Do not run this installer with sudo.'
    log_error 'Run it as your normal user; individual steps request sudo when needed.'
    return 1
  fi

  if ! has_command sudo; then
    log_error 'sudo is required for Ubuntu setup.'
    return 1
  fi
}

set_machine_name() {
  sudo hostnamectl set-hostname "$MACHINE_NAME"
  log_info "Linux name set to $MACHINE_NAME."
}

main() {
  run_step 'Validate Linux' require_linux_or_mac linux
  run_step 'Validate Ubuntu' ensure_supported_linux
  run_step 'Validate user' ensure_normal_user
  run_step 'Load machine identity' configure_machine_identity "$ROOT_DIR/machine.json"
  run_step 'Set Linux name' set_machine_name
  bash "$SHARED_INSTALL_DIR/shared-install-runner.sh"
  log_section 'Done'
  log_info 'Linux install complete.'
}

main "$@"
