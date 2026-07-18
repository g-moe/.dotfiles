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

printf '{\n  "name": "test-vm",\n  "color": "blue",\n  "colorHex": "#458588"\n}\n' >"$temporary_dir/machine.json"
expect_equal "$(machine_field "$temporary_dir/machine.json" name)" test-vm
expect_equal "$(machine_field "$temporary_dir/machine.json" color)" blue
expect_equal "$(machine_field "$temporary_dir/machine.json" colorHex)" '#458588'
expect_equal "$(machine_color_hex blue)" '#458588'
expect_equal "$(machine_color_tint blue)" '0.270588 0.521569 0.533333 0.250000'

magick_log="$temporary_dir/magick.log"
magick() {
  local output=''
  for output in "$@"; do :; done
  printf '%s\n' "$*" >"$magick_log"
  printf 'rendered\n' >"$output"
}
background="$temporary_dir/background.png"
render_machine_background source.png '#458588' 100x50 "$background"
expect_equal "$(cat "$background")" rendered
expect_equal "$(wc -l <"$magick_log" | tr -d ' ')" 1
grep -Fq -- '-resize 100x50!' "$magick_log" ||
  fail 'render_machine_background did not use the requested size'
unset -f magick

curl() {
  local output=''
  while (($#)); do
    case "$1" in
      -o)
        output="$2"
        shift 2
        ;;
      *) shift ;;
    esac
  done
  printf 'archive\n' >"$output"
}
sha256sum() {
  return 0
}
tar() {
  local destination=''
  while (($#)); do
    case "$1" in
      -C)
        destination="$2"
        shift 2
        ;;
      *) shift ;;
    esac
  done
  mkdir -p "$destination/repo-deadbeef"
}
archive_destination="$temporary_dir/archive"
source_directory="$(
  extract_github_source_archive \
    owner/repo deadbeef checksum "$archive_destination"
)"
expect_equal "$source_directory" "$archive_destination/repo-deadbeef"
unset -f curl sha256sum tar

retry_attempts=0
eventually_succeeds() {
  ((retry_attempts += 1))
  ((retry_attempts == 3))
}
retry 3 0 eventually_succeeds || fail 'retry stopped before the command succeeded'
expect_equal "$retry_attempts" 3
if retry 2 0 false; then
  fail 'retry succeeded after every attempt failed'
fi

xfconf_log="$temporary_dir/xfconf.log"
xfconf-query() {
  printf '%s\n' "$*" >>"$xfconf_log"
  if [[ "$*" != *' -s '* && "$*" == *' /missing'* ]]; then
    return 1
  fi
}
xfconf_set test /existing string value
xfconf_set test /missing string value
xfconf_set_array test /existing-array int 1 2
xfconf_set_array test /missing-array int 1 2
grep -Fqx -- '-c test -p /existing -s value' "$xfconf_log" ||
  fail 'xfconf_set did not update an existing value'
grep -Fqx -- '-c test -p /missing -n -t string -s value' "$xfconf_log" ||
  fail 'xfconf_set did not create a missing value'
grep -Fqx -- '-c test -p /existing-array -a -t int -s 1 -t int -s 2' "$xfconf_log" ||
  fail 'xfconf_set_array did not update an existing array'
grep -Fqx -- '-c test -p /missing-array -n -a -t int -s 1 -t int -s 2' "$xfconf_log" ||
  fail 'xfconf_set_array did not create a missing array'
unset -f xfconf-query

source_file="$temporary_dir/source"
target_file="$temporary_dir/links/target"
printf 'source\n' >"$source_file"
safe_symlink "$source_file" "$target_file"
safe_symlink "$source_file" "$target_file"
expect_equal "$(readlink "$target_file")" "$source_file"

existing_file="$temporary_dir/existing-file"
printf 'existing\n' >"$existing_file"
ask_choice() { printf '1\n'; }
safe_symlink "$source_file" "$existing_file"
expect_equal "$(readlink "$existing_file")" "$source_file"

other_source="$temporary_dir/other-source"
existing_link="$temporary_dir/existing-link"
printf 'other\n' >"$other_source"
ln -s "$other_source" "$existing_link"
safe_symlink "$source_file" "$existing_link"
expect_equal "$(readlink "$existing_link")" "$source_file"

skipped_file="$temporary_dir/skipped-file"
printf 'keep\n' >"$skipped_file"
ask_choice() { printf '0\n'; }
safe_symlink "$source_file" "$skipped_file"
expect_equal "$(cat "$skipped_file")" keep

existing_directory="$temporary_dir/existing-directory"
mkdir "$existing_directory"
safe_symlink "$source_file" "$existing_directory"
[[ -d "$existing_directory" ]] || fail 'safe_symlink removed an existing directory'

group_source_a="$temporary_dir/group-source-a"
group_source_b="$temporary_dir/group-source-b"
group_target_a="$temporary_dir/group-target-a"
group_target_b="$temporary_dir/group-target-b"
prompt_log="$temporary_dir/prompts"
printf 'a\n' >"$group_source_a"
printf 'b\n' >"$group_source_b"
printf 'old a\n' >"$group_target_a"
printf 'old b\n' >"$group_target_b"
ask_choice() {
  printf 'prompted\n' >>"$prompt_log"
  printf '1\n'
}
safe_symlink_group 'Test group' \
  "$group_source_a" "$group_target_a" \
  "$group_source_b" "$group_target_b"
expect_equal "$(wc -l <"$prompt_log" | tr -d ' ')" 1
expect_equal "$(readlink "$group_target_a")" "$group_source_a"
expect_equal "$(readlink "$group_target_b")" "$group_source_b"

group_skip_existing="$temporary_dir/group-skip-existing"
group_skip_missing="$temporary_dir/group-skip-missing"
printf 'keep\n' >"$group_skip_existing"
ask_choice() { printf '0\n'; }
safe_symlink_group 'Skipped group' \
  "$group_source_a" "$group_skip_existing" \
  "$group_source_b" "$group_skip_missing"
expect_equal "$(cat "$group_skip_existing")" keep
expect_equal "$(readlink "$group_skip_missing")" "$group_source_b"

has bash || fail 'has did not find Bash'

for function_name in die log log_section run_step ask_choice ask_binary read_value read_secret has retry safe_symlink safe_symlink_group; do
  count="$(grep -h "^${function_name}()" "$BASH_LIB_DIR"/*.sh | wc -l | tr -d ' ')"
  expect_equal "$count" 1
done

printf 'Installer library checks passed.\n'
