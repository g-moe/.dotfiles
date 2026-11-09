#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/test.sh"

strategy="$INSTALLER_DIR/setup/apps/neovim.sh"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT

# Source the strategy so the test can supply an isolated repository and home.
. "$strategy"

fake_root="$temporary_dir/repo with spaces"
fake_home="$temporary_dir/home"
target_root="$fake_home/.config/nvim"
mkdir -p "$fake_root/nvim/lua/plugins" "$target_root/lua/plugins"
printf 'init\n' >"$fake_root/nvim/init.lua"
printf 'theme\n' >"$fake_root/nvim/lua/plugins/theme.lua"

# A link to a repo file that was deleted, plus user items that must be kept.
ln -s "$fake_root/nvim/lua/plugins/removed.lua" "$target_root/lua/plugins/removed.lua"
ln -s "$temporary_dir/elsewhere.lua" "$target_root/lua/plugins/elsewhere.lua"
printf 'keep\n' >"$target_root/lua/plugins/local.lua"

ROOT_DIR="$fake_root"
HOME="$fake_home"

# Both runs must link every repo file and remove only broken repo links.
for run in first repeat; do
  _configure

  for relative in init.lua lua/plugins/theme.lua; do
    target="$target_root/$relative"
    [[ -L "$target" && "$(readlink "$target")" == "$fake_root/nvim/$relative" ]] ||
      fail "Neovim link is incorrect after $run run: $target"
  done
  [[ ! -L "$target_root/lua/plugins/removed.lua" ]] ||
    fail "broken repo link remains after $run run"
  [[ -L "$target_root/lua/plugins/elsewhere.lua" ]] ||
    fail "a link outside the repo was removed after $run run"
  [[ "$(cat "$target_root/lua/plugins/local.lua")" == keep ]] ||
    fail "a local Neovim file changed after $run run"
done
