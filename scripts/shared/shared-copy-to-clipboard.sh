#!/usr/bin/env bash
# Copy stdin to the system clipboard on macOS (pbcopy) or Linux (wl-copy / xclip).
# Symlinked to ~/.local/bin/copy-to-clipboard by the Zsh setup.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

. "$LIB_DIR/lib.sh"

main() {
  if has pbcopy; then
    pbcopy
    return
  fi

  if [[ -n "${WAYLAND_DISPLAY:-}" ]] && has wl-copy; then
    wl-copy
    return
  fi

  if [[ -n "${DISPLAY:-}" ]] && has xclip; then
    xclip -selection clipboard -in
    return
  fi

  die 'No usable clipboard command found (pbcopy, wl-copy, or xclip).'
}

main "$@"
