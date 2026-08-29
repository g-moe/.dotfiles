#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/test.sh"

strategy="$INSTALLER_DIR/setup/agents/skills.sh"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT

# Source the strategy so the test can supply an isolated repository and home.
. "$strategy"
real_root="$ROOT_DIR"

fake_root="$temporary_dir/repo with spaces"
fake_home="$temporary_dir/home"
for skill in alpha beta; do
  mkdir -p "$fake_root/.agents/skills/$skill"
  printf '%s\n' "# $skill" >"$fake_root/.agents/skills/$skill/SKILL.md"
done

for target_root in \
  "$fake_home/.agents/skills" \
  "$fake_home/.codex/skills" \
  "$fake_home/.claude/skills" \
  "$fake_home/.cursor/skills"; do
  mkdir -p "$target_root/stale-directory"
  printf 'stale\n' >"$target_root/stale-file"
  printf 'hidden\n' >"$target_root/.stale-hidden"
  ln -s "$temporary_dir/missing" "$target_root/stale-link"
done
mkdir -p "$fake_home/.codex/skills/.system"
printf 'keep\n' >"$fake_home/.codex/skills/.system/sentinel"

ROOT_DIR="$fake_root"
HOME="$fake_home"

# Reject a redirected root before any target changes.
symlink_home="$temporary_dir/symlink-home"
external_skills="$temporary_dir/external-skills"
mkdir -p "$symlink_home/.agents/skills" "$symlink_home/.cursor" "$external_skills"
printf 'keep\n' >"$symlink_home/.agents/skills/existing"
printf 'external\n' >"$external_skills/sentinel"
ln -s "$external_skills" "$symlink_home/.cursor/skills"
if (HOME="$symlink_home" install_skills mac) >/dev/null 2>&1; then
  fail 'a symlinked skill root must fail'
fi
[[ "$(cat "$external_skills/sentinel")" == external ]] ||
  fail 'a symlinked skill root changed its external target'
[[ "$(cat "$symlink_home/.agents/skills/existing")" == keep ]] ||
  fail 'target validation did not finish before cleanup'

install_skills mac

for target_root in \
  "$fake_home/.agents/skills" \
  "$fake_home/.codex/skills" \
  "$fake_home/.claude/skills" \
  "$fake_home/.cursor/skills"; do
  for skill in alpha beta; do
    target="$target_root/$skill"
    expected="$fake_root/.agents/skills/$skill"
    [[ -L "$target" && "$(readlink "$target")" == "$expected" &&
      -f "$target/SKILL.md" ]] ||
      fail "agent skill link is incorrect: $target"
  done
  [[ ! -e "$target_root/stale-directory" ]] || fail 'stale skill directory remains'
  [[ ! -e "$target_root/stale-file" ]] || fail 'stale skill file remains'
  [[ ! -e "$target_root/.stale-hidden" ]] || fail 'hidden stale skill remains'
  [[ ! -L "$target_root/stale-link" ]] || fail 'stale skill link remains'
done
[[ "$(cat "$fake_home/.codex/skills/.system/sentinel")" == keep ]] ||
  fail 'Codex system skills were not preserved'

# A second run must produce the same complete set.
install_skills linux
for target_root in \
  "$fake_home/.agents/skills" \
  "$fake_home/.claude/skills" \
  "$fake_home/.cursor/skills"; do
  [[ "$(find "$target_root" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" == 2 ]] ||
    fail "unexpected entry remains after repeat install: $target_root"
done
[[ "$(find "$fake_home/.codex/skills" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" == 3 ]] ||
  fail 'Codex skills must contain two links and .system'

# An empty source root must leave the current installation unchanged.
empty_root="$temporary_dir/empty-repo"
failure_home="$temporary_dir/failure-home"
mkdir -p "$empty_root/.agents/skills" "$failure_home/.agents/skills"
printf 'keep\n' >"$failure_home/.agents/skills/existing"
if (ROOT_DIR="$empty_root" HOME="$failure_home" install_skills mac) >/dev/null 2>&1; then
  fail 'an empty source skill root must fail'
fi
[[ "$(cat "$failure_home/.agents/skills/existing")" == keep ]] ||
  fail 'source validation failure changed installed skills'
[[ ! -e "$failure_home/.codex/skills" ]] ||
  fail 'source validation failure created another target root'

# Exercise the strategy as the same child process used by run_strategy.
process_home="$temporary_dir/process-home"
mkdir -p "$process_home/.codex/skills/.system"
printf 'system\n' >"$process_home/.codex/skills/.system/sentinel"
HOME="$process_home" bash "$strategy" mac
for source in "$real_root"/.agents/skills/*; do
  [[ -d "$source" && -f "$source/SKILL.md" ]] || continue
  skill="$(basename "$source")"
  for target_root in \
    "$process_home/.agents/skills" \
    "$process_home/.codex/skills" \
    "$process_home/.claude/skills" \
    "$process_home/.cursor/skills"; do
    [[ -L "$target_root/$skill" && "$(readlink "$target_root/$skill")" == "$source" ]] ||
      fail "child-process skill link is incorrect: $target_root/$skill"
  done
done
[[ "$(cat "$process_home/.codex/skills/.system/sentinel")" == system ]] ||
  fail 'child-process install removed Codex system skills'

printf 'Agent skill replacement checks passed.\n'
