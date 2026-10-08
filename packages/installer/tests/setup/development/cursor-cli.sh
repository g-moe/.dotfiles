#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/test.sh"

# Run the strategy with an isolated home and a fake vendor download.
strategy="$INSTALLER_DIR/setup/development/cursor-cli.sh"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT
mkdir -p "$temporary_dir/bin"

# Reject an incorrect download command and record each installation attempt.
cat >"$temporary_dir/bin/curl" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == '-fsSL https://cursor.com/install' ]] || exit 1
printf 'download\n' >>"$CURSOR_TEST_LOG"
[[ "${CURSOR_TEST_DOWNLOAD_FAIL:-0}" == 0 ]] || exit 22
cat <<'INSTALL'
set -euo pipefail
mkdir -p "$HOME/.local/bin"
if [[ "${CURSOR_TEST_MISSING_CLI:-0}" == 1 ]]; then
  exit 0
fi
cat >"$HOME/.local/bin/cursor-agent" <<'CLI'
#!/usr/bin/env bash
[[ "$*" == '--version' ]] || exit 1
printf 'version\n' >>"$CURSOR_TEST_LOG"
exit "${CURSOR_TEST_VERSION_FAIL:-0}"
CLI
chmod +x "$HOME/.local/bin/cursor-agent"
ln -s cursor-agent "$HOME/.local/bin/agent"
INSTALL
SCRIPT
chmod +x "$temporary_dir/bin/curl"

# Both platforms must install once and check the CLI on every run.
for platform in mac linux; do
  fake_home="$temporary_dir/$platform"
  commands="$temporary_dir/$platform.log"
  mkdir -p "$fake_home"
  for run in 1 2; do
    HOME="$fake_home" PATH="$temporary_dir/bin:$PATH" \
      CURSOR_TEST_LOG="$commands" bash "$strategy" "$platform"
  done
  [[ -x "$fake_home/.local/bin/cursor-agent" && \
    -x "$fake_home/.local/bin/agent" ]] || fail "$platform CLI installation is missing"
  [[ "$(cat "$commands")" == $'download\nversion\nversion' ]] ||
    fail "$platform must install once and check both runs"

  # A broken existing CLI must fail without downloading a replacement.
  if HOME="$fake_home" PATH="$temporary_dir/bin:$PATH" \
    CURSOR_TEST_LOG="$commands" CURSOR_TEST_VERSION_FAIL=1 \
    bash "$strategy" "$platform" >"$temporary_dir/output" 2>&1; then
    fail "$platform must reject a failed version check"
  fi
  [[ "$(grep -c '^download$' "$commands")" == 1 ]] ||
    fail "$platform must preserve the existing installation"
done

# Failed downloads and successful scripts without a CLI must fail setup.
for failure in download missing version; do
  fake_home="$temporary_dir/failure-$failure"
  mkdir -p "$fake_home"
  download_fail=0
  missing_cli=0
  version_fail=0
  case "$failure" in
    download) download_fail=1 ;;
    missing) missing_cli=1 ;;
    version) version_fail=1 ;;
  esac
  if HOME="$fake_home" PATH="$temporary_dir/bin:$PATH" \
    CURSOR_TEST_LOG="$temporary_dir/failure-$failure.log" \
    CURSOR_TEST_DOWNLOAD_FAIL="$download_fail" \
    CURSOR_TEST_MISSING_CLI="$missing_cli" \
    CURSOR_TEST_VERSION_FAIL="$version_fail" \
    bash "$strategy" linux >"$temporary_dir/output" 2>&1; then
    fail "Cursor setup must reject $failure failures"
  fi
done

printf 'Cursor CLI setup checks passed.\n'
