#!/usr/bin/env bash
set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$SETUP_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
. "$SCRIPTS_DIR/lib/lib.sh"

install_skills() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_install() {
  local skill source target target_root

  for target_root in \
    "$HOME/.agents/skills" \
    "$HOME/.codex/skills" \
    "$HOME/.claude/skills" \
    "$HOME/.cursor/skills" \
    "$HOME/.config/opencode/skills"; do
    mkdir -p "$target_root"
    for source in "$ROOT_DIR"/.agents/skills/*; do
      [[ -f "$source/SKILL.md" ]] || continue
      skill="$(basename "$source")"
      target="$target_root/$skill"
      safe_symlink "$source" "$target"
    done
  done
}

mac() {
  _install
}

linux() {
  _install
}

if [[ "$#" -eq 0 ]]; then
  detect_os
  set -- "$OS"
fi
install_skills "$1"
