#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
LIB_DIR="$SCRIPTS_DIR/lib"
TOOLS_DIR="$SCRIPTS_DIR/shared/tools"

. "$LIB_DIR/lib-logging.sh"
. "$LIB_DIR/lib-utils.sh"
. "$LIB_DIR/lib-runtime.sh"

enable_install_error_trap

configure_tpm() {
  local target="$HOME/.tmux/plugins/tpm"
  local tpm_prefix
  local source

  if ! tpm_prefix="$(brew --prefix tpm 2>/dev/null)"; then
    log_error 'The Homebrew tpm formula is required for tmux setup.'
    return 1
  fi
  source="$tpm_prefix/share/tpm"

  if [[ ! -x "$source/tpm" ]]; then
    log_error "Homebrew TPM executable not found: $source/tpm"
    return 1
  fi

  safe_link "$source" "$target"
  "$target/bin/install_plugins"
}

main() {
  if [[ "$(id -u)" -eq 0 ]]; then
    log_error 'Do not run tmux setup as root.'
    exit 1
  fi

  if [[ -z "${HOME:-}" ]]; then
    log_error 'HOME is not set; cannot configure tmux.'
    exit 1
  fi

  if ! load_homebrew; then
    log_error 'Homebrew is required before tmux setup.'
    exit 1
  fi

  if ! has_command tmux; then
    log_error 'tmux is not installed.'
    exit 1
  fi

  safe_link "$ROOT_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
  safe_link "$TOOLS_DIR/shared-copy-to-clipboard.sh" \
    "$HOME/.local/bin/copy-to-clipboard"
  configure_tpm
}

main "$@"
