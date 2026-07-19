#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/test.sh"

tool="$BASH_LIB_DIR/bin/shared-retire-package.sh"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT
mkdir -p "$temporary_dir/bin"
printf '[]\n' >"$temporary_dir/retire.json"

cat >"$temporary_dir/bin/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${TEST_UNAME:-Darwin}"
EOF
cat >"$temporary_dir/bin/brew" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  'list --formula') printf 'old-formula\n' ;;
  'list --cask') printf 'old-cask\n' ;;
  uninstall*) printf '%s\n' "$*" >>"$TEST_COMMANDS" ;;
esac
EOF
cat >"$temporary_dir/bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TEST_COMMANDS"
EOF
chmod +x "$temporary_dir/bin/uname" "$temporary_dir/bin/brew" "$temporary_dir/bin/sudo"

export TEST_COMMANDS="$temporary_dir/commands"
PATH="$temporary_dir/bin:$PATH" RETIRE_FILE="$temporary_dir/retire.json" \
  bash "$tool" old-formula >/dev/null
PATH="$temporary_dir/bin:$PATH" RETIRE_FILE="$temporary_dir/retire.json" \
  bash "$tool" --cask old-cask >/dev/null
TEST_UNAME=Linux PATH="$temporary_dir/bin:$PATH" RETIRE_FILE="$temporary_dir/retire.json" \
  bash "$tool" old-apt >/dev/null

jq -e '
  length == 3 and
  any(.[]; .platform == "mac" and .type == "formula" and .name == "old-formula") and
  any(.[]; .platform == "mac" and .type == "cask" and .name == "old-cask") and
  any(.[]; .platform == "linux" and .manager == "apt" and .name == "old-apt" and (has("type") | not))
' "$temporary_dir/retire.json" >/dev/null || fail 'retire must record Mac and Linux packages'
grep -Fxq 'uninstall --formula old-formula' "$TEST_COMMANDS" || fail 'retire must uninstall a formula'
grep -Fxq 'uninstall --cask old-cask' "$TEST_COMMANDS" || fail 'retire must uninstall a cask'
grep -Fxq 'apt-get remove -y old-apt' "$TEST_COMMANDS" || fail 'retire must uninstall an APT package'

PATH="$temporary_dir/bin:$PATH" RETIRE_FILE="$temporary_dir/retire.json" \
  bash "$tool" old-formula >/dev/null
[[ "$(jq 'length' "$temporary_dir/retire.json")" -eq 3 ]] || fail 'retire must not add duplicates'

commands_before="$(wc -l <"$TEST_COMMANDS" | tr -d ' ')"
printf '[{"platform":"mac","manager":"apt","type":"formula","name":"bad"}]\n' \
  >"$temporary_dir/invalid.json"
cp "$temporary_dir/invalid.json" "$temporary_dir/invalid-before.json"
if PATH="$temporary_dir/bin:$PATH" RETIRE_FILE="$temporary_dir/invalid.json" \
  bash "$tool" old-formula >/dev/null 2>&1; then
  fail 'retire accepted a malformed retirement file'
fi
cmp -s "$temporary_dir/invalid-before.json" "$temporary_dir/invalid.json" ||
  fail 'retire changed a malformed retirement file'
[[ "$(wc -l <"$TEST_COMMANDS" | tr -d ' ')" -eq "$commands_before" ]] ||
  fail 'retire uninstalled a package from a malformed retirement file'

printf 'Retire command checks passed.\n'
