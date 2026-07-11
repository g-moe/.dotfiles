#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LIB_DIR="$SCRIPT_DIR/../../lib"

. "$LIB_DIR/lib-logging.sh"
. "$LIB_DIR/lib-utils.sh"

enable_install_error_trap

main() {
  local source_config="$ROOT_DIR/karabiner/karabiner.json"
  local target_config="${HOME:?HOME is not set}/.config/karabiner/karabiner.json"

  if [[ ! -f "$source_config" ]]; then
    log_error "Missing repo Karabiner config: $source_config"
    exit 1
  fi

  if [[ "$source_config" == "$target_config" ]]; then
    log_info 'Karabiner config already lives at the expected path.'
    return
  fi

  safe_link "$source_config" "$target_config"
  log_info "Linked $target_config -> $source_config"
}

main "$@"
