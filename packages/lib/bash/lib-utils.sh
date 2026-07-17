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

# Create a symlink, asking before replacing an existing file or different link.
# Never replace a real directory.
# Usage: safe_symlink "$ROOT_DIR/ghostty/config" "$HOME/.config/ghostty/config"
safe_symlink() {
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
  if [[ -e "$target" || -L "$target" ]]; then
    [[ ! -d "$target" || -L "$target" ]] || die "Refusing to replace directory $target"
    ask_binary "Replace $target with a symlink?" n || die "Refusing to replace $target"
    rm "$target"
  fi
  ln -s "$source" "$target"
}
