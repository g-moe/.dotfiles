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

# Retry a command until it succeeds or runs out of attempts.
# Usage: retry 20 0.5 command arg
retry() {
  local attempts="$1"
  local delay="$2"
  local attempt
  shift 2

  for ((attempt = 1; attempt <= attempts; attempt++)); do
    "$@" && return 0
    ((attempt == attempts)) || sleep "$delay"
  done
  return 1
}

# Create a symlink. Existing files and different links can be skipped or replaced.
# A supplied choice avoids another prompt: 0 skips, 1 replaces.
# Never replace a real directory.
# Usage: safe_symlink "$ROOT_DIR/ghostty/config" "$HOME/.config/ghostty/config"
safe_symlink() {
  local source="$1"
  local target="$2"
  local choice="${3:-}"

  if [[ ! -e "$source" && ! -L "$source" ]]; then
    die "Link source does not exist: $source"
  fi

  [[ "$source" == "$target" ]] && return
  mkdir -p "$(dirname "$target")"
  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    return
  fi
  if [[ -d "$target" && ! -L "$target" ]]; then
    log "Skipping existing directory $target."
    return 0
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    if [[ -z "$choice" ]]; then
      choice="$(ask_choice "Existing $target:" Skip 'Replace with a symlink')"
    fi
    case "$choice" in
      0) return 0 ;;
      1) rm "$target" ;;
      *) die "Invalid symlink choice: $choice" ;;
    esac
  fi
  ln -s "$source" "$target"
}

# Create a group of symlinks with one choice for all existing files and links.
# Arguments after the label are source/target pairs.
# Usage: safe_symlink_group Ghostty "$source" "$target" ...
safe_symlink_group() {
  local label="$1"
  shift
  local links=("$@")
  local choice=1
  local found_existing=0
  local i source target

  ((${#links[@]} % 2 == 0)) || die 'safe_symlink_group needs source/target pairs.'

  for ((i = 0; i < ${#links[@]}; i += 2)); do
    source="${links[$i]}"
    target="${links[$((i + 1))]}"

    if [[ ! -e "$source" && ! -L "$source" ]]; then
      die "Link source does not exist: $source"
    fi
    if [[ "$source" != "$target" ]] &&
      ! { [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$source" ]]; } &&
      [[ ! -d "$target" || -L "$target" ]] &&
      { [[ -e "$target" ]] || [[ -L "$target" ]]; }; then
      found_existing=1
    fi
  done

  if ((found_existing)); then
    choice="$(ask_choice "Existing items found for $label:" Skip 'Replace with symlinks')"
  fi

  for ((i = 0; i < ${#links[@]}; i += 2)); do
    safe_symlink "${links[$i]}" "${links[$((i + 1))]}" "$choice"
  done
}
