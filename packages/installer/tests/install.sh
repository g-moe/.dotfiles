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
expect_file_contains "$installer" "--retire) printf 'retire" \
  'install.sh must accept --retire'
expect_file_contains "$installer" "--agents) printf 'agents" \
  'install.sh must accept --agents'
if grep -Fq -- '--skills' "$installer"; then
  fail 'install.sh must not expose the retired --skills mode'
fi
if grep -Fq -- '--mactop' "$installer"; then
  fail 'install.sh must not expose a dedicated --mactop mode'
fi
if grep -Fq -- '--mactop' "$INSTALLER_DIR/README.md"; then
  fail 'installer docs must not advertise a dedicated --mactop mode'
fi
expect_file_contains "$installer" \
  "run_strategy 'System monitor' apps/system-monitor.sh" \
  'the normal apps phase must install the repository-owned mactop build'
expect_file_contains "$installer" 'run_retire_packages' \
  'normal app installs must retire recorded packages'
expect_file_contains "$installer" "log 'A reboot is recommended.'" \
  'install.sh must recommend a reboot'
expect_file_contains "$installer" "ask_binary 'Reboot now?' n" \
  'the reboot prompt must default to no'
expect_file_contains "$installer" 'sudo shutdown -r now' \
  'install.sh must use the shared reboot command'
expect_file_contains "$ROOT_DIR/packages/theming/create/controller.ts" '"install:codium"' \
  '--theme must install its VSIX into VSCodium'

main_body="$(sed -n '/^main() {/,/^}/p' "$installer")"
all_branch="$(sed -n '/^    all)/,/^      ;;/p' <<<"$main_body")"
phase_branch="$(sed -n '/^    \*)/,/^      ;;/p' <<<"$main_body")"
grep -Fq "run_strategy 'Machine name and color' identity.sh" <<<"$all_branch" ||
  fail 'the full install must configure machine identity'
if grep -Fq 'install_agents' <<<"$all_branch"; then
  fail 'the full install must not install agent configuration'
fi
if grep -Fq 'identity.sh' <<<"$phase_branch"; then
  fail 'individual phase flags must not configure machine identity'
fi
desktop_line="$(grep -n 'check_linux_desktop' <<<"$main_body" | head -n 1 | cut -d: -f1)"
phase_line="$(grep -n 'run_phase "$mode"' <<<"$main_body" | head -n 1 | cut -d: -f1)"
[[ -n "$desktop_line" && -n "$phase_line" && "$desktop_line" -lt "$phase_line" ]] ||
  fail 'the Linux desktop check must run before normal phases'

finish_install="$(sed -n '/^finish_install() {/,/^}/p' "$installer")"
grep -Fq '[[ "$mode" == all || "$mode" == system ]] || return 0' <<<"$finish_install" ||
  fail 'only full and system runs may offer to reboot'

bad_npm="$(grep -E '"install:(agents|git|machine|theme|retire)"' "$ROOT_DIR/package.json" |
  grep -v 'packages/installer/install\.sh' || true)"
[[ -z "$bad_npm" ]] || fail 'root install commands must call packages/installer/install.sh'
if grep -Fq '"install:skills"' "$ROOT_DIR/package.json"; then
  fail 'package.json must not expose the retired install:skills command'
fi
if grep -Fq '"install:mactop"' "$ROOT_DIR/package.json"; then
  fail 'package.json must not expose a dedicated mactop install command'
fi
expect_file_contains "$ROOT_DIR/package.json" \
  '"test:mactop": "cd packages/mac/mactop && make verify"' \
  'package.json must expose the mactop verification matrix'
expect_file_contains "$ROOT_DIR/package.json" \
  '"install:file-ext": "bash packages/lib/bash/bin/shared-file-ext.sh"' \
  'package.json must expose standalone file associations'
if grep -Fq 'files/associations.sh' "$installer"; then
  fail 'the machine installer must not set VSCodium file associations'
fi

file_ext="$ROOT_DIR/packages/lib/bash/bin/shared-file-ext.sh"
bash -n "$file_ext"
expect_file_contains "$file_ext" 'json yaml yml' \
  'standalone file associations must include JSON'
expect_file_contains "$file_ext" 'Darwin)' \
  'standalone file associations must support macOS'
expect_file_contains "$file_ext" 'Linux)' \
  'standalone file associations must support Linux'
expect_file_contains "$file_ext" 'UTType(filenameExtension: extensionName)' \
  'macOS file associations must use modern UTIs'
expect_file_contains "$file_ext" 'setDefaultApplication(at: application, toOpen: type)' \
  'macOS file associations must use the supported default-application API'
expect_file_contains "$file_ext" 'urlForApplication(toOpen: type) == application' \
  'macOS file associations must verify the Finder handler'

# Exercise the real entry point with isolated strategies and machine checks.
temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT
fixture_root="$temporary_dir/home/.dotfiles"
fixture_installer="$fixture_root/packages/installer"
mkdir -p "$fixture_installer/lib" "$temporary_dir/bin" "$temporary_dir/node-bin"
cp "$installer" "$fixture_installer/install.sh"
cp "$ROOT_DIR/.nvmrc" "$fixture_root/.nvmrc"

for command in bash dirname mkdir cp tr; do
  ln -s "$(command -v "$command")" "$temporary_dir/bin/$command"
done

cat >"$fixture_installer/lib/lib.sh" <<'SCRIPT'
. "$DEVELOPMENT_TEST_LIB"
# OS detection and privilege checks use fixture values, not the host machine.
detect_os() { export OS="$DEVELOPMENT_TEST_OS"; }
validate_os() { [[ "$OS" == mac || "$OS" == linux ]]; }
validate_user() { return 0; }
SCRIPT

while IFS= read -r strategy; do
  mkdir -p "$fixture_installer/setup/$(dirname "$strategy")"
  cat >"$fixture_installer/setup/$strategy" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
case "${BASH_SOURCE[0]}" in
  */system/desktop-environment.sh | */development/git.sh) exit 0 ;;
esac
[[ "$1" == "$DEVELOPMENT_TEST_OS" ]]
# Each consumer checks Node commands from its own process.
node --version
npm --version
npx --version
printf 'consumer %s\n' "${BASH_SOURCE[0]##*/}" >>"$DEVELOPMENT_TEST_LOG"
SCRIPT
done < <(sed -nE "s/.*run_strategy '[^']+' ([^[:space:]]+)$/\\1/p" "$installer")

cat >"$fixture_installer/setup/development/node.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf 'setup\n' >>"$DEVELOPMENT_TEST_LOG"
mkdir -p "$HOME/.nvm"
cp "$DEVELOPMENT_TEST_NVM" "$HOME/.nvm/nvm.sh"
SCRIPT

cat >"$temporary_dir/nvm.sh" <<'SCRIPT'
[[ "$*" == --no-use ]] || return 1
nvm() {
  [[ "$*" == "use $DEVELOPMENT_TEST_NODE_VERSION" ]] || return 1
  [[ "${DEVELOPMENT_TEST_ACTIVATION_FAIL:-0}" == 0 ]] || return 1
  printf 'activate\n' >>"$DEVELOPMENT_TEST_LOG"
  export PATH="$DEVELOPMENT_TEST_NODE_BIN:$PATH"
}
SCRIPT

for command in node npm npx; do
  printf '#!/usr/bin/env bash\n[[ "$*" == --version ]]\n' >"$temporary_dir/node-bin/$command"
  chmod +x "$temporary_dir/node-bin/$command"
done

for platform in mac linux; do
  commands="$temporary_dir/$platform.log"
  HOME="$temporary_dir/home" PATH="$temporary_dir/bin" \
    DEVELOPMENT_TEST_LIB="$INSTALLER_DIR/lib/lib.sh" DEVELOPMENT_TEST_OS="$platform" \
    DEVELOPMENT_TEST_LOG="$commands" DEVELOPMENT_TEST_NVM="$temporary_dir/nvm.sh" \
    DEVELOPMENT_TEST_NODE_BIN="$temporary_dir/node-bin" \
    DEVELOPMENT_TEST_NODE_VERSION="$(tr -d '[:space:]' <"$ROOT_DIR/.nvmrc")" \
    bash "$fixture_installer/install.sh" --development >"$temporary_dir/output" 2>&1 || {
      cat "$temporary_dir/output"
      fail "$platform development consumers must inherit Node after setup"
    }
  [[ "$(head -n 2 "$commands")" == $'setup\nactivate' ]] ||
    fail "$platform must activate Node in the parent after setup"
  for consumer in pi.sh opencode.sh vscodium-extensions.sh; do
    expect_file_contains "$commands" "consumer $consumer" \
      "$platform must run $consumer with Node available"
  done

  : >"$commands"
  if HOME="$temporary_dir/home" PATH="$temporary_dir/bin" \
    DEVELOPMENT_TEST_LIB="$INSTALLER_DIR/lib/lib.sh" DEVELOPMENT_TEST_OS="$platform" \
    DEVELOPMENT_TEST_LOG="$commands" DEVELOPMENT_TEST_NVM="$temporary_dir/nvm.sh" \
    DEVELOPMENT_TEST_NODE_BIN="$temporary_dir/node-bin" \
    DEVELOPMENT_TEST_NODE_VERSION="$(tr -d '[:space:]' <"$ROOT_DIR/.nvmrc")" \
    DEVELOPMENT_TEST_ACTIVATION_FAIL=1 \
    bash "$fixture_installer/install.sh" --development >"$temporary_dir/output" 2>&1; then
    fail "$platform must stop when Node activation fails"
  fi
  [[ "$(cat "$commands")" == setup ]] ||
    fail "$platform must stop before consumers when Node activation fails"
  expect_file_contains "$temporary_dir/output" 'Node.js is not available.' \
    "$platform must explain Node activation failures"
done

printf 'Installer flow checks passed.\n'
