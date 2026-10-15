#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/test.sh"
. "$INSTALLER_DIR/lib/lib.sh"

STRATEGY_DIR="$INSTALLER_DIR/setup/files"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT

# Load only function definitions; never run the machine entry point in a test.
eval "$(sed -n '/^configure_file_sidebar() {/,/^configure_file_sidebar "\$1"/p' \
  "$STRATEGY_DIR/sidebar.sh" | sed '$d')"

# Record prompts and replace every command that could change the real desktop.
ask_choice() {
  printf '%s\n' "$@" >"$case_dir/prompt"
  if [[ -e "$HOME/code" ]]; then
    touch "$case_dir/code-existed-at-prompt"
  fi
  printf '%s\n' "$test_choice"
}

/usr/bin/osascript() {
  [[ "$sidebar_write_fail" == 0 ]] || return 1
  printf '%s\n' "$@" >"$case_dir/arguments"
  printf 'write\n' >>"$case_dir/events"
}

/usr/bin/open() {
  [[ "$sidebar_write_fail" == 0 ]] || return 0
  fail 'sidebar tests must not open System Settings'
}

killall() {
  printf 'refresh %s\n' "$*" >>"$case_dir/events"
}

prepare_case() {
  case_dir="$temporary_dir/$1"
  HOME="$case_dir/home"
  test_choice="$2"
  sidebar_write_fail=0
  mkdir -p "$HOME"
}

expect_no_sidebar_changes() {
  [[ ! -e "$HOME/code" ]] || fail 'setup unexpectedly created the code folder'
  [[ ! -e "$case_dir/arguments" ]] || fail 'setup unexpectedly wrote favorites'
  [[ ! -e "$case_dir/events" ]] || fail 'setup unexpectedly refreshed Finder'
}

expect_sidebar_configured() {
  local folders="$1"
  local expected_arguments=(
    -l JavaScript "$STRATEGY_DIR/finder-sidebar.js"
    "$HOME"
    "$ROOT_DIR"
    "$HOME/code"
    /Applications
    "$folders/Desktop"
    "$folders/Documents"
    "$folders/Downloads"
    "$HOME/Pictures"
    "$HOME/Movies"
  )

  printf '%s\n' "${expected_arguments[@]}" >"$case_dir/expected-arguments"
  cmp "$case_dir/expected-arguments" "$case_dir/arguments" ||
    fail 'the sidebar must use the selected folders in the expected order'
  [[ -d "$HOME/code" ]] || fail 'configured sidebars must create the code folder'

  printf '%s\n' write 'refresh sharedfilelistd' 'refresh Finder' \
    >"$case_dir/expected-events"
  cmp "$case_dir/expected-events" "$case_dir/events" ||
    fail 'setup must write favorites, refresh the service, then refresh Finder'
}

test_skip() (
  prepare_case skip 0

  configure_file_sidebar mac

  expect_no_sidebar_changes
  printf '%s\n' 'Finder sidebar:' Skip 'With iCloud' 'Default (local folders)' \
    >"$case_dir/expected-prompt"
  cmp "$case_dir/expected-prompt" "$case_dir/prompt" ||
    fail 'the sidebar must offer Skip, With iCloud, and Default (local folders)'
)

test_folder_choice() (
  prepare_case "$1" "$2"
  local folders="$HOME"
  if [[ "$test_choice" == 1 ]]; then
    folders="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
  fi
  mkdir -p "$folders/Desktop" "$folders/Documents" "$folders/Downloads"

  configure_file_sidebar mac

  expect_sidebar_configured "$folders"
  [[ ! -e "$case_dir/code-existed-at-prompt" ]] ||
    fail 'the sidebar prompt must precede folder creation'

  # Running again must keep the same paths and reload Finder again.
  rm "$case_dir/events"
  configure_file_sidebar mac
  expect_sidebar_configured "$folders"
)

test_missing_icloud_folder() (
  local missing="$1"
  prepare_case "missing-$missing" 1
  local folders="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
  mkdir -p "$folders/Desktop" "$folders/Documents" "$folders/Downloads"
  rmdir "$folders/$missing"

  if (configure_file_sidebar mac) </dev/null >"$case_dir/output" 2>&1; then
    fail "iCloud setup must reject a missing $missing folder"
  fi

  expect_file_contains "$case_dir/output" "$folders/$missing" \
    'missing iCloud folders must be identified'
  expect_no_sidebar_changes
  [[ ! -e "$folders/$missing" ]] || fail 'setup must not create iCloud folders'
)

test_write_failure() (
  prepare_case write-failure 2
  sidebar_write_fail=1

  if (configure_file_sidebar mac) </dev/null >"$case_dir/output" 2>&1; then
    fail 'sidebar write failures must fail setup'
  fi

  [[ ! -e "$case_dir/events" ]] ||
    fail 'failed sidebar writes must not refresh Finder'
)

main() {
  test_skip
  test_folder_choice icloud 1
  test_folder_choice local 2
  test_missing_icloud_folder Desktop
  test_missing_icloud_folder Documents
  test_missing_icloud_folder Downloads
  test_write_failure

  printf 'Finder sidebar checks passed.\n'
}

main
