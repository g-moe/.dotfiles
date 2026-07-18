#!/usr/bin/env bash
set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$SETUP_DIR/.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_skills() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_install() {
  local skill source target target_root
  local links=()

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
      links+=("$source" "$target")
    done
  done

  safe_symlink_group 'Agent skills' "${links[@]}"
}

mac() {
  _install
}

linux() {
  _install
}

[[ "$#" -eq 1 ]] || die 'Run via: bash packages/installer/install.sh --skills'
install_skills "$1"
