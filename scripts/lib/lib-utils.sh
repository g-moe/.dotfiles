#!/usr/bin/env bash

# Command and safe-link helpers.

# Run a command suppressing stdout and stderr.
# Usage: if silent command -v brew; then ...
silent() {
  "$@" >/dev/null 2>&1
}

# Check if a command exists in PATH.
# Usage: if has brew; then ...
has() {
  silent command -v "$1"
}

# Older standalone tools use the longer name.
has_command() {
  has "$@"
}

# Create a symlink without replacing user-owned files, directories, or links.
link_config() {
  local source="$1"
  local target="$2"

  if [[ ! -e "$source" && ! -L "$source" ]]; then
    die "Link source does not exist: $source"
  fi

  [[ "$source" == "$target" ]] && return
  mkdir -p "$(dirname "$target")"
  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    return
  fi
  [[ ! -e "$target" && ! -L "$target" ]] || die "Refusing to replace $target"
  ln -s "$source" "$target"
}
