#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test.sh"

installer="$INSTALLER_DIR/install.sh"
bash -n "$installer"
expect_file_contains "$installer" 'activate_repo_node "$ROOT_DIR"' \
  'install.sh must activate the repo Node version before --theme'
expect_file_contains "$installer" 'load_homebrew ||' \
  'install.sh must load Homebrew before --theme on macOS'
expect_file_contains "$installer" "log 'A reboot is recommended.'" \
  'install.sh must recommend a reboot'
expect_file_contains "$installer" "ask_binary 'Reboot now?' n" \
  'the reboot prompt must default to no'
expect_file_contains "$installer" 'sudo shutdown -r now' \
  'install.sh must use the shared reboot command'
expect_file_contains "$ROOT_DIR/packages/theming/create/controller.ts" '"install:codium"' \
  '--theme must install its VSIX into VSCodium'

main_body="$(sed -n '/^main() {/,/^}/p' "$installer")"
desktop_line="$(grep -n 'check_linux_desktop' <<<"$main_body" | head -n 1 | cut -d: -f1)"
phase_line="$(grep -n 'run_phase "$mode"' <<<"$main_body" | head -n 1 | cut -d: -f1)"
[[ -n "$desktop_line" && -n "$phase_line" && "$desktop_line" -lt "$phase_line" ]] ||
  fail 'the Linux desktop check must run before normal phases'

finish_install="$(sed -n '/^finish_install() {/,/^}/p' "$installer")"
grep -Fq '[[ "$mode" == all || "$mode" == system ]] || return 0' <<<"$finish_install" ||
  fail 'only full and system runs may offer to reboot'

bad_npm="$(grep -E '"install:(git|skills|machine|theme)"' "$ROOT_DIR/package.json" |
  grep -v 'packages/installer/install\.sh' || true)"
[[ -z "$bad_npm" ]] || fail 'root install commands must call packages/installer/install.sh'

printf 'Installer flow checks passed.\n'
