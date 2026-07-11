#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

. "$LIB_DIR/lib-get-linux-or-mac.sh"
. "$LIB_DIR/lib-interactive.sh"
. "$LIB_DIR/lib-logging.sh"
. "$LIB_DIR/lib-runtime.sh"
. "$LIB_DIR/lib-utils.sh"

enable_install_error_trap

ensure_not_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    log_error 'Do not run this script with sudo.'
    log_error 'Run as your normal user so individual steps can request sudo when needed.'
    exit 1
  fi
}

run_shared_installer() {
  bash "$SCRIPT_DIR/shared/install/shared-install-runner.sh"
}

run_mac_script() {
  bash "$SCRIPT_DIR/mac/install/$1"
}

configure_power_mode() {
  local choice mode
  choice="$(interactive_select 'Choose a power mode configuration:' 'Skip' 'Normal' 'Server')"

  case "$choice" in
    0)
      log_info 'Skipping power mode configuration.'
      return
      ;;
    1) mode=normal ;;
    2) mode=server ;;
  esac

  run_with_node "$ROOT_DIR/.nvmrc" "$SCRIPT_DIR/mac/install/mac-power-mode.mts" "$mode"
  log_info "$mode power mode applied."
}

main() {
  run_step 'Validate macOS' require_linux_or_mac mac
  run_step 'Validate user' ensure_not_root
  run_step 'Shared install' run_shared_installer
  run_step 'Install optional Mac software' run_mac_script mac-software-setup.sh
  run_step 'Configure Karabiner' run_mac_script mac-karabiner-setup.sh
  run_step 'Set Mac system settings' run_mac_script mac-system-settings.sh
  run_step 'Configure power mode' configure_power_mode
  log_section 'Done'
  log_info 'Mac install complete.'
}

main "$@"
