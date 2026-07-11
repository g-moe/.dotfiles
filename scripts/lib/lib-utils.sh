#!/usr/bin/env bash

# Command, privilege, and safe-link helpers.

# Run a command suppressing stdout and stderr.
# Usage: if silent command -v brew; then ...
silent() {
  "$@" >/dev/null 2>&1
}

# Check if a command exists in PATH.
# Usage: if has_command brew; then ...
has_command() {
  command -v "$1" >/dev/null 2>&1
}

# Create a symlink without replacing user-owned files or directories.
# Existing symlinks may be updated; an already-correct symlink is left alone.
safe_link() {
  local source="$1"
  local target="$2"
  local current_target

  if [[ ! -e "$source" && ! -L "$source" ]]; then
    log_error "Link source does not exist: $source"
    return 1
  fi

  if [[ -L "$target" ]]; then
    current_target="$(readlink "$target")"
    if [[ "$current_target" == "$source" ]]; then
      log_info "Link already configured: $target -> $source"
      return 0
    fi

    rm "$target"
  elif [[ -e "$target" ]]; then
    log_error "Refusing to replace non-symlink: $target"
    return 1
  fi

  mkdir -p "$(dirname "$target")"
  ln -s "$source" "$target"
  log_info "Linked $target -> $source"
}

run_privileged() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
    return
  fi

  if ! has_command sudo; then
    log_error "sudo is required to run: $*"
    return 1
  fi

  sudo "$@"
}

# Check if a Homebrew cask is installed.
# Usage: if brew_has_cask tailscale-app; then ...
brew_has_cask() {
  brew list --cask "$1" >/dev/null 2>&1
}

# Check if a Homebrew formula is installed.
# Usage: if brew_has_formula tailscale; then ...
brew_has_formula() {
  brew list --formula "$1" >/dev/null 2>&1
}
