#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/test.sh"
helper="$INSTALLER_DIR/setup/agents/cursor-rules.mjs"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT
source_file="$temporary_dir/AGENTS.md"
fake_home="$temporary_dir/home"
plugin="$fake_home/.cursor/plugins/local/garrett-instructions"
printf '# Rules\n\nUse exact instructions.\n' >"$source_file"

# First and repeat runs must produce the same rule without changing other plugins.
mkdir -p "$fake_home/.cursor/plugins/local/personal"
printf 'keep\n' >"$fake_home/.cursor/plugins/local/personal/sentinel"
node "$helper" write "$source_file" "$fake_home"
cp "$plugin/rules/global.mdc" "$temporary_dir/expected.mdc"
node "$helper" write "$source_file" "$fake_home"
node "$helper" check "$source_file" "$fake_home"
cmp -s "$plugin/rules/global.mdc" "$temporary_dir/expected.mdc" || fail 'Repeat changed the rule'
[[ "$(cat "$fake_home/.cursor/plugins/local/personal/sentinel")" == keep ]] ||
  fail 'Cursor rule setup changed another plugin'
node --input-type=module - "$plugin" "$source_file" <<'JS'
import fs from 'node:fs';
const [plugin, source] = process.argv.slice(2);
const manifest = JSON.parse(fs.readFileSync(`${plugin}/.cursor-plugin/plugin.json`, 'utf8'));
const rule = fs.readFileSync(`${plugin}/rules/global.mdc`, 'utf8');
if (manifest.name !== 'garrett-instructions' || manifest.rules !== 'rules') throw Error('Invalid manifest');
if (!rule.startsWith('---\n') || !rule.includes('\nalwaysApply: true\n---\n\n')) throw Error('Rule is not always applied');
if (!rule.endsWith(fs.readFileSync(source, 'utf8'))) throw Error('Instruction text changed');
JS

# A changed source must fail verification until setup refreshes the generated copy.
printf '\nNew instruction.\n' >>"$source_file"
if node "$helper" check "$source_file" "$fake_home" >"$temporary_dir/output" 2>&1; then
  fail 'Cursor verification accepted stale instructions'
fi
node "$helper" write "$source_file" "$fake_home"
node "$helper" check "$source_file" "$fake_home"

# Reject external symlinks at the plugin root, its parents, or its component files.
for relative in .cursor .cursor/plugins/local/garrett-instructions .cursor/plugins/local/garrett-instructions/rules/global.mdc; do
  bad_home="$temporary_dir/escape-${relative//\//-}"
  external="$temporary_dir/external-${relative//\//-}"
  mkdir -p "$external" "$(dirname "$bad_home/$relative")"
  printf 'keep\n' >"$external/sentinel"
  ln -s "$external" "$bad_home/$relative"
  if node "$helper" write "$source_file" "$bad_home" >"$temporary_dir/output" 2>&1; then
    fail "Cursor setup accepted a symlink at $relative"
  fi
  [[ "$(cat "$external/sentinel")" == keep ]] || fail 'Cursor setup changed external data'
  [[ ! -e "$bad_home/.cursor/plugins/local/garrett-instructions/.cursor-plugin/plugin.json" ]] ||
    fail 'Cursor setup wrote a partial plugin before validation'
done

# Refuse another plugin owner rather than replace a same-path personal plugin.
printf '{"name":"personal"}\n' >"$plugin/.cursor-plugin/plugin.json"
if node "$helper" write "$source_file" "$fake_home" >"$temporary_dir/output" 2>&1; then
  fail 'Cursor setup replaced another plugin owner'
fi
printf 'Cursor global instruction checks passed.\n'
