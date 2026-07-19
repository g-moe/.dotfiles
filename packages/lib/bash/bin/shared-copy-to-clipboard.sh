#!/usr/bin/env bash
# Copy stdin to the system clipboard on macOS (pbcopy) or Linux X11 (xclip).
# Symlinked to ~/.local/bin/copy-to-clipboard by the Zsh setup.

set -euo pipefail

SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do
  SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" == /* ]] || SOURCE="$SCRIPT_DIR/$SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

. "$LIB_DIR/lib.sh"

main() {
  if has pbcopy; then
    pbcopy
    return
  fi

  if [[ -n "${DISPLAY:-}" ]] && has xclip; then
    xclip -selection clipboard -in
    return
  fi

  die 'No usable clipboard command found (pbcopy or xclip).'
}

main "$@"
