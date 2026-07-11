#!/usr/bin/env bash
set -euo pipefail

main() {
  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy
    return
  fi

  if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy >/dev/null 2>&1; then
    wl-copy
    return
  fi

  if [[ -n "${DISPLAY:-}" ]] && command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard -in
    return
  fi

  printf '%s\n' \
    'ERROR: No usable clipboard command found (pbcopy, wl-copy, or xclip).' >&2
  return 1
}

main "$@"
