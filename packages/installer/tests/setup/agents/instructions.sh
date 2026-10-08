#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/test.sh"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT

# Run only the instruction boundary in an isolated home. The full strategy also
# builds the usage CLI, which is outside this configuration test.
link_function="$(sed -n '/^_link_instructions() {/,/^}/p' "$INSTALLER_DIR/setup/agents.sh")"
for mode in default xdg override; do
  fake_home="$temporary_dir/$mode"
  mkdir -p "$fake_home"
  xdg_dir=''
  override_dir=''
  case "$mode" in
    default) target="$fake_home/.config/opencode" ;;
    xdg) xdg_dir="$fake_home/config"; target="$xdg_dir/opencode" ;;
    override)
      xdg_dir="$fake_home/config"
      override_dir="$fake_home/custom-opencode"
      target="$override_dir"
      ;;
  esac
  for run in 1 2; do
    HOME="$fake_home" XDG_CONFIG_HOME="$xdg_dir" OPENCODE_CONFIG_DIR="$override_dir" \
      bash -c 'set -euo pipefail; . "$1/lib/lib.sh"; ROOT_DIR="$2"; eval "$3"; _link_instructions' \
      bash "$INSTALLER_DIR" "$ROOT_DIR" "$link_function" >"$temporary_dir/output"
  done
  [[ -L "$target/AGENTS.md" && "$(readlink "$target/AGENTS.md")" == "$ROOT_DIR/.agents/AGENTS.md" ]] ||
    fail "$mode OpenCode instructions have the wrong source"
  cmp -s "$target/AGENTS.md" "$ROOT_DIR/.agents/AGENTS.md" ||
    fail "$mode OpenCode instructions cannot be read"
done

printf 'Global instruction link checks passed.\n'
