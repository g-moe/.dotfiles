#!/usr/bin/env bash
set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$SETUP_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_skills() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_validate_skill_root() {
  local target_root="$1"

  [[ ! -L "$target_root" ]] || die "Agent skill root must not be a symlink: $target_root"
  [[ ! -e "$target_root" || -d "$target_root" ]] ||
    die "Agent skill root must be a directory: $target_root"
}

_replace_skill_root() {
  local target_root="$1"
  local preserve_system="$2"
  local entry skill source target
  shift 2

  mkdir -p "$target_root"
  while IFS= read -r -d '' entry; do
    if [[ "$preserve_system" == 1 && "$entry" == "$target_root/.system" ]]; then
      continue
    fi
    rm -rf -- "$entry"
  done < <(find "$target_root" -mindepth 1 -maxdepth 1 -print0)

  for source in "$@"; do
    skill="$(basename "$source")"
    target="$target_root/$skill"
    ln -s "$source" "$target"
  done

  for source in "$@"; do
    skill="$(basename "$source")"
    target="$target_root/$skill"
    [[ -L "$target" && "$(readlink "$target")" == "$source" &&
      -d "$target" && -f "$target/SKILL.md" ]] ||
      die "Agent skill link is incorrect: $target"
  done
}

_replace_skill_roots() {
  local source target_root source_root="$ROOT_DIR/.agents/skills"
  local sources=()
  local target_roots=(
    "$HOME/.agents/skills"
    "$HOME/.codex/skills"
    "$HOME/.claude/skills"
    "$HOME/.cursor/skills"
  )

  for source in "$source_root"/*; do
    [[ -d "$source" && -f "$source/SKILL.md" ]] || continue
    sources+=("$source")
  done
  ((${#sources[@]} > 0)) || die "No valid agent skills found in $source_root"

  for target_root in "${target_roots[@]}"; do
    _validate_skill_root "$target_root"
  done

  _replace_skill_root "${target_roots[0]}" 0 "${sources[@]}"
  _replace_skill_root "${target_roots[1]}" 1 "${sources[@]}"
  _replace_skill_root "${target_roots[2]}" 0 "${sources[@]}"
  _replace_skill_root "${target_roots[3]}" 0 "${sources[@]}"
}

mac() {
  _replace_skill_roots
}

linux() {
  _replace_skill_roots
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  [[ "$#" -eq 1 ]] || die 'Run via: bash packages/installer/install.sh --agents'
  install_skills "$1"
fi
