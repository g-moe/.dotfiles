#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/test.sh"
. "$INSTALLER_DIR/lib/lib.sh"

temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT

valid="$temporary_dir/valid.json"
cat >"$valid" <<'EOF'
[
  {"platform":"mac","manager":"brew","type":"formula","name":"old-formula"},
  {"platform":"mac","manager":"brew","type":"cask","name":"old-cask"},
  {"platform":"linux","manager":"apt","name":"old-apt"}
]
EOF
validate_retire_file "$valid"

invalid_entries=(
  '{"platform":"mac","manager":"apt","type":"formula","name":"wrong-manager"}'
  '{"platform":"mac","manager":"brew","name":"missing-type"}'
  '{"platform":"linux","manager":"apt","type":"formula","name":"extra-type"}'
  '{"platform":"linux","manager":"apt","name":"bad name"}'
  '{"platform":"other","manager":"apt","name":"wrong-platform"}'
  '{"platform":"linux","manager":"apt","name":"extra-field","note":"no"}'
)
for entry in "${invalid_entries[@]}"; do
  printf '[%s]\n' "$entry" >"$temporary_dir/invalid.json"
  if (validate_retire_file "$temporary_dir/invalid.json") 2>/dev/null; then
    fail "retire validation accepted: $entry"
  fi
done

duplicate='{"platform":"linux","manager":"apt","name":"duplicate"}'
printf '[%s,%s]\n' "$duplicate" "$duplicate" >"$temporary_dir/duplicates.json"
if (validate_retire_file "$temporary_dir/duplicates.json") 2>/dev/null; then
  fail 'retire validation accepted duplicate entries'
fi

printf 'Package retirement validation checks passed.\n'
