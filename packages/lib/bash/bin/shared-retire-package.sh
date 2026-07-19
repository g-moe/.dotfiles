#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$BIN_DIR/../lib.sh"

: "${RETIRE_FILE:=}"
usage='Use: retire [--formula|--cask] package [package ...]'

record_package() {
  local platform="$1"
  local manager="$2"
  local type="$3"
  local name="$4"
  local temporary_file

  temporary_file="$(mktemp)"
  jq --arg platform "$platform" --arg manager "$manager" --arg type "$type" --arg name "$name" '
    if any(.[]; .platform == $platform and .manager == $manager and (.type // "") == $type and .name == $name)
    then .
    else . + [if $type == "" then {platform: $platform, manager: $manager, name: $name}
      else {platform: $platform, manager: $manager, type: $type, name: $name} end]
    end
    | sort_by(.platform, .manager, .type // "", .name)
  ' "$RETIRE_FILE" >"$temporary_file"
  chmod 0644 "$temporary_file"
  mv "$temporary_file" "$RETIRE_FILE"
}

brew_type() {
  local requested_type="$1"
  local name="$2"
  local formula=false cask=false

  if [[ -n "$requested_type" ]]; then
    printf '%s\n' "$requested_type"
    return
  fi
  brew list --formula -1 | grep -Fxq "$name" && formula=true
  brew list --cask -1 | grep -Fxq "$name" && cask=true
  if [[ "$formula" == "$cask" ]]; then
    die "Could not choose formula or cask for $name; pass --formula or --cask."
  fi
  [[ "$formula" == true ]] && printf 'formula\n' || printf 'cask\n'
}

main() {
  local requested_type='' platform manager name type

  case "${1:-}" in
    --formula | --cask)
      requested_type="${1#--}"
      shift
      ;;
  esac
  (($# > 0)) || die "$usage"
  [[ -n "$RETIRE_FILE" && -f "$RETIRE_FILE" ]] || die 'RETIRE_FILE must point to retire.json.'
  command -v jq >/dev/null 2>&1 || die 'jq is required; run npm run install:retire first.'
  validate_retire_file "$RETIRE_FILE"

  case "$(uname -s)" in
    Darwin) platform=mac; manager=brew ;;
    Linux) platform=linux; manager=apt ;;
    *) die 'Only macOS and Linux are supported.' ;;
  esac

  for name in "$@"; do
    [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9+._:@/-]*$ ]] || die "Invalid package name: $name"
    if [[ "$platform" == mac ]]; then
      command -v brew >/dev/null 2>&1 || die 'Homebrew is required.'
      type="$(brew_type "$requested_type" "$name")"
      record_package "$platform" "$manager" "$type" "$name"
      brew uninstall "--$type" "$name"
    else
      [[ -z "$requested_type" ]] || die '--formula and --cask are only valid on macOS.'
      record_package "$platform" "$manager" '' "$name"
      sudo apt-get remove -y "$name"
    fi
    printf 'Retired %s. Commit retire.json to share this change.\n' "$name"
  done
}

main "$@"
