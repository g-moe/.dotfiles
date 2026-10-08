#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/test.sh"
strategy="$INSTALLER_DIR/setup/development/opencode.sh"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT
mkdir -p "$temporary_dir/bin"

# Replace npm so neither platform test changes the machine or uses the network.
cat >"$temporary_dir/bin/npm" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == "install --global --prefix $HOME/.local opencode-ai" ]] || exit 1
printf 'install\n' >>"$OPENCODE_TEST_LOG"
[[ "${OPENCODE_TEST_INSTALL_FAIL:-0}" == 0 ]] || exit 1
[[ "${OPENCODE_TEST_MISSING_CLI:-0}" == 0 ]] || exit 0
mkdir -p "$HOME/.local/bin"
cat >"$HOME/.local/bin/opencode" <<'CLI'
#!/usr/bin/env bash
[[ "$*" == '--version' ]] || exit 1
printf 'version\n' >>"$OPENCODE_TEST_LOG"
exit "${OPENCODE_TEST_VERSION_FAIL:-0}"
CLI
chmod +x "$HOME/.local/bin/opencode"
SCRIPT
chmod +x "$temporary_dir/bin/npm"

# Check first and repeat runs for each supported platform and Linux architecture.
for platform in mac linux-amd64 linux-arm64; do
  fake_home="$temporary_dir/$platform"
  commands="$temporary_dir/$platform.log"
  mkdir -p "$fake_home"
  for run in 1 2; do
    HOME="$fake_home" PATH="$temporary_dir/bin:$PATH" \
      LINUX_ARCH="${platform#linux-}" OPENCODE_TEST_LOG="$commands" \
      bash "$strategy" "${platform%%-*}"
  done
  [[ "$(cat "$commands")" == $'install\nversion\nversion' ]] ||
    fail "$platform must install once and check both runs"

  if HOME="$fake_home" PATH="$temporary_dir/bin:$PATH" \
    OPENCODE_TEST_LOG="$commands" OPENCODE_TEST_VERSION_FAIL=1 \
    bash "$strategy" "${platform%%-*}" >"$temporary_dir/output" 2>&1; then
    fail "$platform must reject a broken installed CLI"
  fi
  [[ "$(grep -c '^install$' "$commands")" == 1 ]] ||
    fail "$platform must preserve the installed CLI"
done

# Installation errors and a missing executable must fail the strategy.
for failure in install missing; do
  fake_home="$temporary_dir/failure-$failure"
  mkdir -p "$fake_home"
  install_fail=0
  missing_cli=0
  [[ "$failure" != install ]] || install_fail=1
  [[ "$failure" != missing ]] || missing_cli=1
  if HOME="$fake_home" PATH="$temporary_dir/bin:$PATH" \
    OPENCODE_TEST_LOG="$temporary_dir/$failure.log" \
    OPENCODE_TEST_INSTALL_FAIL="$install_fail" \
    OPENCODE_TEST_MISSING_CLI="$missing_cli" \
    bash "$strategy" linux >"$temporary_dir/output" 2>&1; then
    fail "OpenCode setup must reject $failure failures"
  fi
done

printf 'OpenCode installation checks passed.\n'
