#!/usr/bin/env bash

# Resolve Homebrew without assuming the current shell loaded its environment.
find_homebrew_bin() {
  local candidate
  local -a candidates
  local kernel

  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return
  fi

  kernel="$(uname -s)"
  case "$kernel" in
    Darwin) candidates=(/opt/homebrew/bin/brew /usr/local/bin/brew) ;;
    Linux) candidates=(/home/linuxbrew/.linuxbrew/bin/brew) ;;
    *) return 1 ;;
  esac

  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  return 1
}

load_homebrew() {
  local brew_bin
  brew_bin="$(find_homebrew_bin)" || return 1
  eval "$("$brew_bin" shellenv)"
  command -v brew >/dev/null 2>&1
}

load_nvm() {
  local home_dir="${HOME:-}"
  if [[ -z "$home_dir" ]]; then
    printf '%s\n' 'ERROR: HOME is not set; cannot load nvm.' >&2
    return 1
  fi

  export NVM_DIR="${NVM_DIR:-$home_dir/.nvm}"

  local nvm_script="$NVM_DIR/nvm.sh"
  local restore_nounset=0
  local status=0

  if [[ ! -s "$nvm_script" ]]; then
    return 1
  fi

  if [[ "$-" == *u* ]]; then
    restore_nounset=1
    set +u
  fi

  # shellcheck disable=SC1090
  . "$nvm_script" --no-use || status=$?

  if [[ "$restore_nounset" -eq 1 ]]; then
    set -u
  fi

  return "$status"
}

run_nvm() {
  local restore_nounset=0
  local status=0

  if [[ "$-" == *u* ]]; then
    restore_nounset=1
    set +u
  fi

  nvm "$@" || status=$?

  if [[ "$restore_nounset" -eq 1 ]]; then
    set -u
  fi

  return "$status"
}

node_version_from_file() {
  local version_file="$1"
  local version

  if [[ ! -f "$version_file" ]]; then
    printf 'ERROR: Node version file not found: %s\n' "$version_file" >&2
    return 1
  fi

  version="$(tr -d '[:space:]' < "$version_file")"
  if [[ -z "$version" ]]; then
    printf 'ERROR: Node version file is empty: %s\n' "$version_file" >&2
    return 1
  fi

  printf '%s\n' "$version"
}

use_node_from_file() {
  local version_file="$1"
  local version
  local node_path
  local node_bin_dir

  version="$(node_version_from_file "$version_file")" || return
  load_nvm || {
    printf 'ERROR: nvm is not installed at %s.\n' \
      "${NVM_DIR:-${HOME:-unknown}/.nvm}" >&2
    return 1
  }
  run_nvm use --silent "$version"

  node_path="$(run_nvm which "$version")" || return
  if [[ ! -x "$node_path" ]]; then
    printf 'ERROR: nvm did not resolve an executable Node.js: %s\n' \
      "$node_path" >&2
    return 1
  fi

  node_bin_dir="$(dirname "$node_path")"
  export PATH="$node_bin_dir:$PATH"
  hash -r
}

# Run a JavaScript or TypeScript file directly with the selected Node version.
# Usage: run_with_node /path/to/.nvmrc /path/to/script.mts [arguments...]
run_with_node() {
  local version_file="$1"
  local script_path="$2"
  shift 2

  use_node_from_file "$version_file"

  if [[ ! -f "$script_path" ]]; then
    printf 'ERROR: Node script not found: %s\n' "$script_path" >&2
    return 1
  fi

  node "$script_path" "$@"
}
