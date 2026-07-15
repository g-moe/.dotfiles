#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

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
link_config "$source_file" "$target_file"
link_config "$source_file" "$target_file"
expect_equal "$(readlink "$target_file")" "$source_file"
if (link_config "$source_file" "$temporary_dir/machine.json" 2>/dev/null); then
  fail 'link_config replaced an existing file'
fi

has bash || fail 'has did not find Bash'

for function_name in die log log_section run_step choose read_value read_secret confirm has link_config; do
  count="$(grep -h "^${function_name}()" "$SCRIPTS_DIR"/lib/*.sh | wc -l | tr -d ' ')"
  expect_equal "$count" 1
done

printf 'Installer library checks passed.\n'
