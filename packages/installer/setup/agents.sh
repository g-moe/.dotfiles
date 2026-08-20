#!/usr/bin/env bash
set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$SETUP_DIR/.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_agents() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_link_instructions() {
  safe_symlink_group 'Agent instructions' \
    "$ROOT_DIR/.agents/AGENTS.md" "$HOME/.codex/AGENTS.md" \
    "$ROOT_DIR/.agents/AGENTS.md" "$HOME/.pi/agent/AGENTS.md" \
    "$ROOT_DIR/.agents/AGENTS.md" "$HOME/.claude/AGENTS.md" \
    "$ROOT_DIR/.agents/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
}

_link_skills() {
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
  _link_instructions
  _link_skills
}

linux() {
  _link_instructions
  _link_skills
}

[[ "$#" -eq 1 ]] || die 'Run via: bash packages/installer/install.sh --agents'
install_agents "$1"
