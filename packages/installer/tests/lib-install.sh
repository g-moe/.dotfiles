#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
BASH_LIB_DIR="$ROOT_DIR/packages/lib/bash"
. "$INSTALLER_DIR/lib/lib.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

expect_equal() {
  [[ "$1" == "$2" ]] || fail "expected '$2', found '$1'"
}

temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT

printf '{\n  "name": "test-vm",\n  "color": "blue"\n}\n' >"$temporary_dir/machine.json"
expect_equal "$(machine_field "$temporary_dir/machine.json" name)" test-vm
expect_equal "$(machine_field "$temporary_dir/machine.json" color)" blue
expect_equal "$(machine_color_hex blue)" '#458588'
expect_equal "$(machine_color_tint blue)" '0.270588 0.521569 0.533333 0.250000'

source_file="$temporary_dir/source"
target_file="$temporary_dir/links/target"
printf 'source\n' >"$source_file"
safe_symlink "$source_file" "$target_file"
safe_symlink "$source_file" "$target_file"
expect_equal "$(readlink "$target_file")" "$source_file"

existing_file="$temporary_dir/existing-file"
printf 'existing\n' >"$existing_file"
ask_binary() { return 0; }
safe_symlink "$source_file" "$existing_file"
expect_equal "$(readlink "$existing_file")" "$source_file"

other_source="$temporary_dir/other-source"
existing_link="$temporary_dir/existing-link"
printf 'other\n' >"$other_source"
ln -s "$other_source" "$existing_link"
safe_symlink "$source_file" "$existing_link"
expect_equal "$(readlink "$existing_link")" "$source_file"

declined_file="$temporary_dir/declined-file"
printf 'keep\n' >"$declined_file"
ask_binary() { return 1; }
if (safe_symlink "$source_file" "$declined_file" 2>/dev/null); then
  fail 'safe_symlink replaced a declined file'
fi
expect_equal "$(cat "$declined_file")" keep

existing_directory="$temporary_dir/existing-directory"
mkdir "$existing_directory"
ask_binary() { return 0; }
if (safe_symlink "$source_file" "$existing_directory" 2>/dev/null); then
  fail 'safe_symlink replaced an existing directory'
fi
[[ -d "$existing_directory" ]] || fail 'safe_symlink removed an existing directory'

has bash || fail 'has did not find Bash'

for function_name in die log log_section run_step ask_choice ask_binary read_value read_secret has safe_symlink; do
  count="$(grep -h "^${function_name}()" "$BASH_LIB_DIR"/*.sh | wc -l | tr -d ' ')"
  expect_equal "$count" 1
done

printf 'Installer library checks passed.\n'
