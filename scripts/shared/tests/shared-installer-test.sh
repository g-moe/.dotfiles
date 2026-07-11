#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
TEST_DIR="$(mktemp -d)"
PASS_COUNT=0

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'ok %d - %s\n' "$PASS_COUNT" "$1"
}

assert_equal() {
  local expected="$1"
  local actual="$2"
  local message="$3"
  [[ "$actual" == "$expected" ]] || fail "$message (expected '$expected', got '$actual')"
}

assert_file_contains() {
  local file="$1"
  local text="$2"
  local message="$3"
  grep -Fq -- "$text" "$file" || fail "$message"
}

assert_before() {
  local file="$1"
  local first="$2"
  local second="$3"
  local message="$4"
  local first_line second_line

  first_line="$(grep -nF -- "$first" "$file" | head -n 1 | cut -d: -f1)"
  second_line="$(grep -nF -- "$second" "$file" | head -n 1 | cut -d: -f1)"
  if [[ -z "$first_line" || -z "$second_line" || "$first_line" -ge "$second_line" ]]; then
    fail "$message"
  fi
}

write_fake_uname() {
  local directory="$1"
  mkdir -p "$directory"
  cat >"$directory/uname" <<'EOF'
#!/bin/bash
case "${1:-}" in
  -s) printf '%s\n' "${FAKE_UNAME_S:-Darwin}" ;;
  -m) printf '%s\n' "${FAKE_UNAME_M:-arm64}" ;;
  *) printf '%s\n' "${FAKE_UNAME_S:-Darwin}" ;;
esac
EOF
  chmod +x "$directory/uname"
}

test_machine_routing() {
  local fake_bin="$TEST_DIR/machine-bin"
  local helper="$SCRIPTS_DIR/lib/lib-get-linux-or-mac.sh"
  local actual
  write_fake_uname "$fake_bin"

  actual="$(FAKE_UNAME_S=Darwin PATH="$fake_bin:$PATH" /bin/bash -c \
    '. "$1"; get_linux_or_mac' _ "$helper")"
  assert_equal mac "$actual" 'Darwin must route to mac'

  actual="$(FAKE_UNAME_S=Linux PATH="$fake_bin:$PATH" /bin/bash -c \
    '. "$1"; get_linux_or_mac' _ "$helper")"
  assert_equal linux "$actual" 'Linux must route to linux'

  actual="$(FAKE_UNAME_S=Darwin PATH="$fake_bin:$PATH" /bin/bash -c \
    '. "$1"; mac() { printf mac-branch; }; linux() { printf linux-branch; }; dispatch_linux_or_mac' _ "$helper")"
  assert_equal mac-branch "$actual" 'dispatch must call only the Mac function'

  if FAKE_UNAME_S=FreeBSD PATH="$fake_bin:$PATH" /bin/bash -c \
    '. "$1"; get_linux_or_mac' _ "$helper" >/dev/null 2>&1; then
    fail 'unsupported systems must fail'
  fi
  pass 'machine detection and fixed routing'
}

test_safe_links() {
  local source_a="$TEST_DIR/source-a"
  local source_b="$TEST_DIR/source-b"
  local target="$TEST_DIR/links/config"
  local real_target="$TEST_DIR/links/real"

  . "$SCRIPTS_DIR/lib/lib-logging.sh"
  . "$SCRIPTS_DIR/lib/lib-utils.sh"

  printf a >"$source_a"
  printf b >"$source_b"
  safe_link "$source_a" "$target" >/dev/null
  assert_equal "$source_a" "$(readlink "$target")" 'safe_link must create the link'

  safe_link "$source_a" "$target" >/dev/null
  assert_equal "$source_a" "$(readlink "$target")" 'a correct link must stay correct on rerun'

  ln -sfn "$TEST_DIR/missing" "$target"
  safe_link "$source_b" "$target" >/dev/null
  assert_equal "$source_b" "$(readlink "$target")" 'a broken or wrong link must be replaced'

  printf mine >"$real_target"
  if safe_link "$source_a" "$real_target" >/dev/null 2>&1; then
    fail 'safe_link must refuse a real file'
  fi
  assert_equal mine "$(cat "$real_target")" 'safe_link must not change a real file'
  pass 'safe links are safe and repeatable'
}

make_clipboard_command() {
  local directory="$1"
  local name="$2"
  mkdir -p "$directory"
  cat >"$directory/$name" <<'EOF'
#!/bin/bash
printf '%s %s\n' "${0##*/}" "$*" >>"$CALL_LOG"
/bin/cat >"$CLIPBOARD_CAPTURE"
EOF
  chmod +x "$directory/$name"
}

test_clipboard_routing() {
  local clipboard="$SCRIPTS_DIR/shared/tools/shared-copy-to-clipboard.sh"
  local capture="$TEST_DIR/clipboard-capture"
  local calls="$TEST_DIR/clipboard-calls"
  local provider_dir

  provider_dir="$TEST_DIR/pbcopy-bin"
  make_clipboard_command "$provider_dir" pbcopy
  printf mac | CALL_LOG="$calls" CLIPBOARD_CAPTURE="$capture" PATH="$provider_dir" \
    /bin/bash "$clipboard"
  assert_equal mac "$(cat "$capture")" 'pbcopy must receive clipboard input'

  : >"$calls"
  provider_dir="$TEST_DIR/wayland-bin"
  make_clipboard_command "$provider_dir" wl-copy
  printf wayland | WAYLAND_DISPLAY=wayland-0 CALL_LOG="$calls" CLIPBOARD_CAPTURE="$capture" \
    PATH="$provider_dir" /bin/bash "$clipboard"
  assert_equal wayland "$(cat "$capture")" 'wl-copy must receive Wayland input'

  : >"$calls"
  provider_dir="$TEST_DIR/x11-bin"
  make_clipboard_command "$provider_dir" xclip
  printf x11 | DISPLAY=:0 CALL_LOG="$calls" CLIPBOARD_CAPTURE="$capture" \
    PATH="$provider_dir" /bin/bash "$clipboard"
  assert_equal x11 "$(cat "$capture")" 'xclip must receive X11 input'
  assert_file_contains "$calls" 'xclip -selection clipboard -in' 'xclip must select the clipboard'

  mkdir -p "$TEST_DIR/empty-bin"
  if PATH="$TEST_DIR/empty-bin" /bin/bash "$clipboard" </dev/null >/dev/null 2>&1; then
    fail 'clipboard setup must fail when no provider exists'
  fi
  pass 'clipboard routing for Mac, Wayland, X11, and failure'
}

test_fresh_process_runner() {
  local fixture="$TEST_DIR/runner/scripts"
  local install_dir="$fixture/shared/install"
  local log="$TEST_DIR/runner.log"
  local name
  local actual_order
  local unique_pids

  mkdir -p "$fixture/lib" "$install_dir"
  cp "$SCRIPTS_DIR/shared/install/shared-install-runner.sh" "$install_dir/"
  cat >"$fixture/lib/lib-logging.sh" <<'EOF'
enable_install_error_trap() { :; }
run_step() { shift; "$@"; }
EOF

  for name in \
    shared-homebrew-setup.sh \
    shared-apps-setup.sh \
    shared-machine-name-menu-bar.sh \
    shared-node-setup.sh \
    shared-zsh-setup.sh \
    shared-tmux-setup.sh \
    shared-tailscale-setup.sh; do
    cat >"$install_dir/$name" <<'EOF'
#!/bin/bash
printf '%s|%s|%s\n' "$(basename "$0")" "$$" "$*" >>"$RUN_LOG"
EOF
  done

  RUN_LOG="$log" /bin/bash "$install_dir/shared-install-runner.sh"
  actual_order="$(awk -F'|' '{print $1}' "$log")"
  assert_equal "$(printf '%s\n' \
    shared-homebrew-setup.sh \
    shared-apps-setup.sh \
    shared-machine-name-menu-bar.sh \
    shared-node-setup.sh \
    shared-zsh-setup.sh \
    shared-tmux-setup.sh \
    shared-tailscale-setup.sh)" "$actual_order" 'shared setup order changed'

  unique_pids="$(awk -F'|' '{print $2}' "$log" | sort -u | wc -l | tr -d ' ')"
  assert_equal 7 "$unique_pids" 'each setup domain must run in a fresh Bash process'
  assert_file_contains "$log" 'shared-tailscale-setup.sh|' 'runner must call Tailscale'
  assert_file_contains "$log" '|install' 'runner must use Tailscale install mode only'
  pass 'shared runner order and fresh processes'
}

make_entrypoint_fixture() {
  local fixture="$1"
  local fake_bin="$fixture/fake-bin"
  local log="$2"
  local name

  mkdir -p "$fixture/scripts/lib" "$fixture/scripts/shared/install" \
    "$fixture/scripts/mac/install" "$fake_bin"
  cp "$SCRIPTS_DIR/lib/lib-get-linux-or-mac.sh" "$fixture/scripts/lib/"
  cp "$SCRIPTS_DIR/lib/lib-machine-identity.sh" "$fixture/scripts/lib/"
  cp "$SCRIPTS_DIR/mac-install.sh" "$fixture/scripts/"

  cat >"$fixture/scripts/lib/lib-logging.sh" <<'EOF'
enable_install_error_trap() { :; }
log_error() { printf 'ERROR: %s\n' "$1" >&2; }
log_info() { :; }
log_section() { :; }
run_step() { shift; "$@"; }
EOF
  cat >"$fixture/scripts/lib/lib-interactive.sh" <<'EOF'
interactive_select() { printf '0\n'; }
interactive_read() {
  printf 'machine-name\n' >>"$PROMPT_LOG"
  printf '%s\n' "${MACHINE_NAME_ANSWER:-Test-Mac}"
}
interactive_confirm() {
  printf 'change-machine\n' >>"$PROMPT_LOG"
  [[ "${CHANGE_MACHINE_IDENTITY:-0}" == '1' ]]
}
EOF
  cat >"$fixture/scripts/lib/lib-runtime.sh" <<'EOF'
run_with_node() { printf 'node\n' >>"$ENTRY_LOG"; }
EOF
  cat >"$fixture/scripts/lib/lib-utils.sh" <<'EOF'
has_command() { command -v "$1" >/dev/null 2>&1; }
EOF
  cat >"$fixture/scripts/shared/install/shared-install-runner.sh" <<'EOF'
#!/bin/bash
printf 'shared\n' >>"$ENTRY_LOG"
EOF
  for name in mac-software-setup.sh mac-karabiner-setup.sh mac-system-settings.sh; do
    cat >"$fixture/scripts/mac/install/$name" <<'EOF'
#!/bin/bash
printf '%s\n' "$(basename "$0")" >>"$ENTRY_LOG"
printf '%s|%s\n' "$MACHINE_NAME" "$MACHINE_COLOR" >>"$MACHINE_LOG"
EOF
  done

  write_fake_uname "$fake_bin"
  cat >"$fake_bin/id" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == '-u' ]]; then printf '501\n'; else printf 'tester\n'; fi
EOF
  cat >"$fake_bin/sudo" <<'EOF'
#!/bin/bash
printf 'sudo %s\n' "$*" >>"$SYSTEM_LOG"
EOF
  cat >"$fake_bin/apt-get" <<'EOF'
#!/bin/bash
printf 'apt-get %s\n' "$*" >>"$SYSTEM_LOG"
EOF
  cat >"$fake_bin/systemctl" <<'EOF'
#!/bin/bash
printf 'systemctl %s\n' "$*" >>"$SYSTEM_LOG"
EOF
  chmod +x "$fake_bin"/* "$fixture/scripts/shared/install/shared-install-runner.sh" \
    "$fixture/scripts/mac/install"/*.sh
  : >"$log"
}

test_mac_entrypoint() {
  local fixture="$TEST_DIR/mac-entry"
  local log="$TEST_DIR/mac-entry.log"
  local system_log="$TEST_DIR/mac-system.log"
  local machine_log="$TEST_DIR/mac-machine.log"
  local prompt_log="$TEST_DIR/mac-prompt.log"
  local fake_bin="$fixture/fake-bin"

  make_entrypoint_fixture "$fixture" "$log"
  : >"$system_log"
  : >"$machine_log"
  : >"$prompt_log"
  FAKE_UNAME_S=Darwin ENTRY_LOG="$log" SYSTEM_LOG="$system_log" \
    MACHINE_LOG="$machine_log" PROMPT_LOG="$prompt_log" \
    PATH="$fake_bin:/usr/bin:/bin" /bin/bash "$fixture/scripts/mac-install.sh"

  assert_equal "$(printf '%s\n' shared mac-software-setup.sh mac-karabiner-setup.sh mac-system-settings.sh)" \
    "$(cat "$log")" 'Mac entrypoint order changed'
  assert_file_contains "$fixture/machine.json" '"name": "test-mac"' 'Mac entrypoint must save the machine name'
  assert_file_contains "$fixture/machine.json" '"color": "blue"' 'Mac entrypoint must save the machine color'
  assert_equal "$(printf '%s\n' 'test-mac|blue' 'test-mac|blue' 'test-mac|blue')" \
    "$(cat "$machine_log")" 'Mac entrypoint must pass machine identity to child steps'
  assert_file_contains "$system_log" 'scutil --set ComputerName test-mac' 'Mac entrypoint must set ComputerName'
  assert_file_contains "$system_log" 'scutil --set LocalHostName test-mac' 'Mac entrypoint must set LocalHostName'
  assert_file_contains "$system_log" 'scutil --set HostName test-mac' 'Mac entrypoint must set HostName'

  : >"$log"
  : >"$prompt_log"
  FAKE_UNAME_S=Darwin ENTRY_LOG="$log" SYSTEM_LOG="$system_log" \
    MACHINE_LOG="$machine_log" PROMPT_LOG="$prompt_log" \
    PATH="$fake_bin:/usr/bin:/bin" /bin/bash "$fixture/scripts/mac-install.sh"
  assert_equal 'change-machine' "$(cat "$prompt_log")" \
    'Mac entrypoint must ask before reusing an existing machine identity'

  : >"$prompt_log"
  CHANGE_MACHINE_IDENTITY=1 MACHINE_NAME_ANSWER=Other-Mac \
    FAKE_UNAME_S=Darwin ENTRY_LOG="$log" SYSTEM_LOG="$system_log" \
    MACHINE_LOG="$machine_log" PROMPT_LOG="$prompt_log" \
    PATH="$fake_bin:/usr/bin:/bin" /bin/bash "$fixture/scripts/mac-install.sh"
  assert_equal "$(printf '%s\n' change-machine machine-name)" "$(cat "$prompt_log")" \
    'Mac entrypoint must ask for new values when changing machine identity'
  assert_file_contains "$fixture/machine.json" '"name": "other-mac"' \
    'Mac entrypoint must replace the saved machine identity'
  pass 'Mac entrypoint creates, reuses, and changes machine identity'
}

test_mac_power_mode() {
  local fake_bin="$TEST_DIR/power-bin"
  local command_log="$TEST_DIR/power-command.log"
  local error_log="$TEST_DIR/power-error.log"
  local power_script="$SCRIPTS_DIR/mac/install/mac-power-mode.mts"

  mkdir -p "$fake_bin"
  cat >"$fake_bin/pmset" <<'EOF'
#!/bin/bash
printf '%s\n' 'Capabilities for AC Power:' ' lowpowermode'
if [[ "${FAKE_HIGH_POWER:-0}" == '1' ]]; then
  printf '%s\n' ' highpowermode'
fi
EOF
  cat >"$fake_bin/sudo" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$POWER_COMMAND_LOG"
EOF
  chmod +x "$fake_bin/pmset" "$fake_bin/sudo"

  : >"$command_log"
  PATH="$fake_bin:$PATH" POWER_COMMAND_LOG="$command_log" \
    node "$power_script" server 2>"$error_log"
  assert_file_contains "$command_log" 'pmset -a' 'power mode must use pmset'
  assert_file_contains "$command_log" 'powermode 1' 'unsupported High Power Mode must fall back to balanced'
  assert_file_contains "$command_log" 'autorestart 1' 'server mode must restart after power loss'
  assert_file_contains "$error_log" 'using balanced mode' 'High Power Mode fallback must be explained'
  if grep -Fq 'systemsetup' "$command_log"; then
    fail 'power mode must not use failing systemsetup commands'
  fi
  if grep -Fq 'MODULE_TYPELESS_PACKAGE_JSON' "$error_log"; then
    fail 'power mode must not print a Node module warning'
  fi

  : >"$command_log"
  FAKE_HIGH_POWER=1 PATH="$fake_bin:$PATH" POWER_COMMAND_LOG="$command_log" \
    node "$power_script" server 2>"$error_log"
  assert_file_contains "$command_log" 'powermode 2' 'supported High Power Mode must be enabled for server mode'
  pass 'Mac power mode capability fallback and restart setting'
}

make_linux_entrypoint() {
  local fixture="$1"
  local os_release="$2"
  local cpu_info="$3"

  cp "$SCRIPTS_DIR/linux-install.sh" "$fixture/scripts/linux-install.sh.source"
  sed \
    -e "s|/etc/os-release|$os_release|g" \
    -e "s|/proc/cpuinfo|$cpu_info|g" \
    "$fixture/scripts/linux-install.sh.source" >"$fixture/scripts/linux-install.sh"
}

test_linux_entrypoint() {
  local fixture="$TEST_DIR/linux-entry"
  local log="$TEST_DIR/linux-entry.log"
  local system_log="$TEST_DIR/linux-system.log"
  local fake_bin="$fixture/fake-bin"
  local os_release="$TEST_DIR/os-release"
  local cpu_info="$TEST_DIR/cpuinfo"

  make_entrypoint_fixture "$fixture" "$log"
  printf 'ID=ubuntu\nVERSION_ID=26.04\n' >"$os_release"
  printf 'flags : ssse3\n' >"$cpu_info"
  make_linux_entrypoint "$fixture" "$os_release" "$cpu_info"
  : >"$system_log"

  FAKE_UNAME_S=Linux FAKE_UNAME_M=aarch64 ENTRY_LOG="$log" SYSTEM_LOG="$system_log" \
    MACHINE_LOG="$TEST_DIR/linux-machine.log" PROMPT_LOG="$TEST_DIR/linux-prompt.log" \
    PATH="$fake_bin:/usr/bin:/bin" /bin/bash "$fixture/scripts/linux-install.sh"
  assert_equal shared "$(cat "$log")" 'Linux entrypoint did not run the shared installer'
  assert_file_contains "$fixture/machine.json" '"name": "test-mac"' 'Linux entrypoint must save the machine name'
  assert_file_contains "$system_log" 'hostnamectl set-hostname test-mac' 'Linux entrypoint must set the hostname'

  printf 'ID=ubuntu\nVERSION_ID=24.04\n' >"$os_release"
  : >"$log"
  : >"$system_log"
  if FAKE_UNAME_S=Linux FAKE_UNAME_M=aarch64 ENTRY_LOG="$log" SYSTEM_LOG="$system_log" \
    PATH="$fake_bin:/usr/bin:/bin" /bin/bash "$fixture/scripts/linux-install.sh" >/dev/null 2>&1; then
    fail 'an unsupported Ubuntu version must fail'
  fi
  [[ ! -s "$log" && ! -s "$system_log" ]] || fail 'unsupported Ubuntu changed state'

  printf 'ID=ubuntu\nVERSION_ID=26.04\n' >"$os_release"
  printf 'flags : sse2\n' >"$cpu_info"
  if FAKE_UNAME_S=Linux FAKE_UNAME_M=x86_64 ENTRY_LOG="$log" SYSTEM_LOG="$system_log" \
    PATH="$fake_bin:/usr/bin:/bin" /bin/bash "$fixture/scripts/linux-install.sh" >/dev/null 2>&1; then
    fail 'x86_64 without SSSE3 must fail'
  fi
  [[ ! -s "$log" && ! -s "$system_log" ]] || fail 'unsupported CPU changed state'
  pass 'Ubuntu 26.04 entrypoint and pre-write rejection'
}

test_machine_name_menu_bar() {
  local script="$SCRIPTS_DIR/shared/install/shared-machine-name-menu-bar.sh"
  local fake_bin="$TEST_DIR/menu-bar-bin"
  local linux_home="$TEST_DIR/linux-home"
  local mac_home="$TEST_DIR/mac-home"
  local call_log="$TEST_DIR/menu-bar-calls.log"
  local swift_capture="$TEST_DIR/menu-bar.swift"

  write_fake_uname "$fake_bin"
  cat >"$fake_bin/gnome-shell" <<'EOF'
#!/bin/bash
printf 'GNOME Shell 50.1\n'
EOF
  cat >"$fake_bin/gnome-extensions" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$CALL_LOG"
EOF
  cat >"$fake_bin/gsettings" <<'EOF'
#!/bin/bash
if [[ "$1" == 'get' ]]; then
  printf '@as []\n'
else
  printf '%s\n' "$*" >>"$CALL_LOG"
fi
EOF
  cat >"$fake_bin/xcrun" <<'EOF'
#!/bin/bash
printf 'xcrun %s\n' "$*" >>"$CALL_LOG"
/bin/cat >"$SWIFT_CAPTURE"
printf '#!/bin/bash\n' >"$3"
/bin/chmod +x "$3"
EOF
  cat >"$fake_bin/launchctl" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$CALL_LOG"
EOF
  chmod +x "$fake_bin"/*

  : >"$call_log"
  FAKE_UNAME_S=Linux MACHINE_NAME=linux-box HOME="$linux_home" CALL_LOG="$call_log" \
    PATH="$fake_bin:/usr/bin:/bin" /bin/bash "$script" >/dev/null
  assert_file_contains "$linux_home/.local/share/gnome-shell/extensions/machine-name@local/metadata.json" \
    '"shell-version": ["50"]' 'GNOME extension must match the installed shell version'
  assert_file_contains "$linux_home/.local/share/gnome-shell/extensions/machine-name@local/extension.js" \
    "text: 'machine:linux-box'" 'GNOME extension must show the prefixed machine name'
  assert_file_contains "$call_log" 'enable machine-name@local' 'GNOME extension must be enabled'
  assert_file_contains "$call_log" "set org.gnome.shell enabled-extensions ['machine-name@local']" \
    'GNOME extension must stay enabled after login'

  : >"$call_log"
  FAKE_UNAME_S=Darwin MACHINE_NAME=mac-box HOME="$mac_home" CALL_LOG="$call_log" \
    SWIFT_CAPTURE="$swift_capture" PATH="$fake_bin:/usr/bin:/bin" /bin/bash "$script" >/dev/null
  [[ -x "$mac_home/.local/bin/machine-name-menu-bar" ]] || fail 'Mac menu bar program must be executable'
  assert_file_contains "$swift_capture" 'NSStatusBar.system.statusItem' 'Mac program must create a native menu bar item'
  assert_file_contains "$mac_home/Library/LaunchAgents/local.machine-name-menu-bar.plist" \
    '<string>machine:mac-box</string>' 'Mac login job must pass the prefixed machine name'
  assert_file_contains "$call_log" 'bootstrap gui/' 'Mac login job must be started'
  FAKE_UNAME_S=Darwin MACHINE_NAME=mac-box HOME="$mac_home" CALL_LOG="$call_log" \
    SWIFT_CAPTURE="$swift_capture" PATH="$fake_bin:/usr/bin:/bin" /bin/bash "$script" >/dev/null
  assert_equal 1 "$(grep -c '^xcrun ' "$call_log")" 'unchanged Mac menu bar program must not be recompiled'
  pass 'native machine name menu bars for Mac and GNOME'
}

make_tailscale_fixture() {
  local fixture="$1"
  local fake_bin="$fixture/fake-bin"

  mkdir -p "$fixture/scripts/lib" "$fixture/scripts/shared/install" "$fake_bin"
  sed '$d' "$SCRIPTS_DIR/shared/install/shared-tailscale-setup.sh" \
    >"$fixture/scripts/shared/install/shared-tailscale-setup.sh"

  cat >"$fixture/scripts/lib/lib-get-linux-or-mac.sh" <<'EOF'
dispatch_linux_or_mac() { :; }
EOF
  cat >"$fixture/scripts/lib/lib-interactive.sh" <<'EOF'
interactive_select() { printf '1\n'; }
EOF
  cat >"$fixture/scripts/lib/lib-logging.sh" <<'EOF'
enable_install_error_trap() { :; }
log_error() { printf 'ERROR: %s\n' "$1" >&2; }
log_info() { :; }
EOF
  cat >"$fixture/scripts/lib/lib-runtime.sh" <<'EOF'
load_homebrew() { :; }
EOF
  cat >"$fixture/scripts/lib/lib-utils.sh" <<'EOF'
has_command() { command -v "$1" >/dev/null 2>&1; }
brew_has_formula() { [[ -f "$FORMULA_STATE" ]]; }
brew_has_cask() { return 1; }
EOF

  cat >"$fake_bin/brew" <<'EOF'
#!/bin/bash
printf 'brew[%s] %s\n' "${FAKE_BREW_SCOPE:-user}" "$*" >>"$BREW_LOG"
printf 'brew[%s] %s\n' "${FAKE_BREW_SCOPE:-user}" "$*" >>"$EVENT_LOG"
case "${1:-} ${2:-}" in
  'services list') printf 'tailscale none\n' ;;
  'install --formula') touch "$FORMULA_STATE" ;;
esac
EOF
  cat >"$fake_bin/systemctl" <<'EOF'
#!/bin/bash
printf 'systemctl %s\n' "$*" >>"$SYSTEM_LOG"
printf 'systemctl %s\n' "$*" >>"$EVENT_LOG"
command_name="${1:-}"
unit=''
for argument in "$@"; do unit="$argument"; done
case "$command_name" in
  is-active)
    if [[ "$unit" == 'tailscaled.service' ]]; then
      [[ "${VENDOR_ACTIVE:-0}" == '1' ]]
    else
      [[ -f "$CUSTOM_ACTIVE_STATE" ]]
    fi
    ;;
  list-unit-files)
    if [[ "${VENDOR_INSTALLED:-0}" == '1' ]]; then
      printf 'tailscaled.service enabled\n'
    fi
    ;;
  restart)
    touch "$CUSTOM_ACTIVE_STATE"
    ;;
esac
EOF
  cat >"$fake_bin/sudo" <<'EOF'
#!/bin/bash
printf 'sudo %s\n' "$*" >>"$SUDO_LOG"
command_path="$1"
shift
case "${command_path##*/}" in
  brew)
    FAKE_BREW_SCOPE=system "$command_path" "$@"
    ;;
  cmp)
    if [[ -f "$CAPTURED_UNIT" ]]; then
      /usr/bin/cmp "$2" "$CAPTURED_UNIT"
    else
      exit 1
    fi
    ;;
  install)
    /bin/cp "$3" "$CAPTURED_UNIT"
    ;;
  systemctl)
    "$command_path" "$@"
    ;;
  *)
    "$command_path" "$@"
    ;;
esac
EOF
  chmod +x "$fake_bin"/*
}

run_fake_tailscale_install() {
  local fixture="$1"
  local vendor_installed="$2"
  local daemon="$fixture/tailscaled"

  printf '#!/bin/bash\n' >"$daemon"
  chmod +x "$daemon"

  FIXTURE="$fixture" VENDOR_INSTALLED="$vendor_installed" /bin/bash -c '
    set -euo pipefail
    export PATH="$FIXTURE/fake-bin:/usr/bin:/bin"
    export BREW_LOG="$FIXTURE/brew.log"
    export SUDO_LOG="$FIXTURE/sudo.log"
    export SYSTEM_LOG="$FIXTURE/system.log"
    export EVENT_LOG="$FIXTURE/events.log"
    export FORMULA_STATE="$FIXTURE/formula-installed"
    export CUSTOM_ACTIVE_STATE="$FIXTURE/custom-active"
    export CAPTURED_UNIT="$FIXTURE/linux-tailscaled.service"
    export VENDOR_ACTIVE=0
    export VENDOR_INSTALLED
    export CONFIGURE_LOG="$FIXTURE/configure.log"
    . "$FIXTURE/scripts/shared/install/shared-tailscale-setup.sh"
    LINUX_TAILSCALED_BIN="$FIXTURE/tailscaled"
    configure_cli() { printf configure >>"$CONFIGURE_LOG"; }
    install_linux
  '
}

test_fake_tailscale_lifecycle() {
  local fixture="$TEST_DIR/tailscale"
  local restart_count

  make_tailscale_fixture "$fixture"
  : >"$fixture/brew.log"
  : >"$fixture/sudo.log"
  : >"$fixture/system.log"
  : >"$fixture/configure.log"
  : >"$fixture/events.log"

  run_fake_tailscale_install "$fixture" 0
  assert_file_contains "$fixture/brew.log" 'brew[user] services stop tailscale' 'user Brew service was not stopped'
  assert_file_contains "$fixture/brew.log" 'brew[system] services stop tailscale' 'system Brew service was not stopped'
  assert_file_contains "$fixture/brew.log" 'brew[user] services list' 'user Brew service was not verified'
  assert_file_contains "$fixture/brew.log" 'brew[system] services list' 'system Brew service was not verified'
  assert_file_contains "$fixture/brew.log" 'brew[user] install --formula tailscale' 'Tailscale formula was not installed as the user'
  assert_file_contains "$fixture/system.log" 'systemctl list-unit-files tailscaled.service --no-legend' 'vendor service was not checked'
  assert_file_contains "$fixture/system.log" 'systemctl daemon-reload' 'systemd was not reloaded'
  assert_file_contains "$fixture/system.log" 'systemctl enable linux-tailscaled.service' 'custom service was not enabled'
  assert_file_contains "$fixture/system.log" 'systemctl restart linux-tailscaled.service' 'custom service was not restarted'
  assert_file_contains "$fixture/system.log" 'systemctl is-active --quiet linux-tailscaled.service' 'custom service was not verified'
  assert_file_contains "$fixture/linux-tailscaled.service" '--port=41641' 'rendered service is missing its port'
  [[ ! -s "$fixture/configure.log" ]] || fail 'Tailscale install called configure mode'
  assert_before "$fixture/events.log" 'brew[user] services stop tailscale' \
    'brew[system] services stop tailscale' 'user Brew service must stop before the system Brew service'
  assert_before "$fixture/events.log" 'brew[system] services list' \
    'systemctl list-unit-files tailscaled.service --no-legend' 'Brew services must be verified before the vendor service check'
  assert_before "$fixture/events.log" 'systemctl list-unit-files tailscaled.service --no-legend' \
    'brew[user] install --formula tailscale' 'vendor collision must be checked before formula installation'
  assert_before "$fixture/events.log" 'brew[user] install --formula tailscale' \
    'systemctl daemon-reload' 'formula installation must finish before systemd setup'
  assert_before "$fixture/events.log" 'systemctl restart linux-tailscaled.service' \
    'systemctl is-active --quiet linux-tailscaled.service' 'service must restart before active verification'

  run_fake_tailscale_install "$fixture" 0
  restart_count="$(grep -c 'systemctl restart linux-tailscaled.service' "$fixture/system.log")"
  assert_equal 2 "$restart_count" 'Tailscale must restart on every install rerun'
  assert_equal 1 "$(grep -c '^sudo install ' "$fixture/sudo.log")" 'unchanged systemd service must not be rewritten'

  : >"$fixture/system.log"
  if run_fake_tailscale_install "$fixture" 1 >/dev/null 2>&1; then
    fail 'an installed vendor Tailscale service must block installation'
  fi
  if grep -q 'systemctl restart linux-tailscaled.service' "$fixture/system.log"; then
    fail 'vendor service collision must stop before custom service writes'
  fi
  pass 'fake Tailscale service lifecycle, rerun, and collision refusal'
}

test_tailscale_contract() {
  local tailscale="$SCRIPTS_DIR/shared/install/shared-tailscale-setup.sh"
  local runner="$SCRIPTS_DIR/shared/install/shared-install-runner.sh"

  assert_file_contains "$runner" 'shared-tailscale-setup.sh install' 'runner must not configure Tailscale'
  assert_file_contains "$tailscale" '"$brew_bin" services stop tailscale' 'user Homebrew service is not stopped'
  assert_file_contains "$tailscale" 'sudo "$brew_bin" services stop tailscale' 'system Homebrew service is not stopped'
  assert_file_contains "$tailscale" 'list-unit-files tailscaled.service' 'vendor service collision is not checked'
  assert_file_contains "$tailscale" "LINUX_SERVICE_NAME='linux-tailscaled.service'" 'custom Linux service name changed'
  assert_file_contains "$tailscale" "LINUX_TAILSCALED_BIN='/home/linuxbrew/.linuxbrew/opt/tailscale/bin/tailscaled'" 'stable Tailscale binary changed'
  assert_file_contains "$tailscale" '--port=41641' 'Tailscale UDP port is missing'
  assert_file_contains "$tailscale" 'ExecStopPost=-' 'Tailscale cleanup is missing'
  assert_file_contains "$tailscale" 'systemctl daemon-reload' 'systemd reload is missing'
  assert_file_contains "$tailscale" 'systemctl enable' 'systemd enable is missing'
  assert_file_contains "$tailscale" 'systemctl restart' 'Tailscale must restart on every install'
  assert_file_contains "$tailscale" 'systemctl is-active --quiet "$LINUX_SERVICE_NAME"' 'active service verification is missing'
  assert_file_contains "$tailscale" 'shared-tailscale-setup.sh configure' 'CLI install must print the configure command'

  if /bin/bash "$tailscale" unsupported >/dev/null 2>&1; then
    fail 'Tailscale must reject unknown modes'
  fi
  if /bin/bash "$tailscale" install extra >/dev/null 2>&1; then
    fail 'Tailscale must reject extra arguments'
  fi
  pass 'Tailscale install/configure and service contract'
}

test_one_brewfile_and_environment_loading() {
  local brewfile_count
  local bad_lib_count
  local brewfile="$SCRIPTS_DIR/shared/install/shared-Brewfile"
  brewfile_count="$(find "$SCRIPTS_DIR" -type f -name '*Brewfile' | wc -l | tr -d ' ')"
  assert_equal 1 "$brewfile_count" 'there must be exactly one Brewfile'
  assert_file_contains "$brewfile" 'if OS.mac?' 'Brewfile needs a Mac branch'
  assert_file_contains "$brewfile" 'if OS.linux?' 'Brewfile needs a Linux branch'
  assert_file_contains "$brewfile" 'brew "tmux"' 'shared tmux formula is missing'
  assert_file_contains "$brewfile" 'brew "zsh"' 'Linux Zsh formula is missing'
  assert_file_contains "$brewfile" 'brew "wl-clipboard"' 'Wayland clipboard formula is missing'

  assert_file_contains "$SCRIPTS_DIR/shared/install/shared-apps-setup.sh" 'load_homebrew' 'app child must reload Homebrew'
  assert_file_contains "$SCRIPTS_DIR/shared/install/shared-tmux-setup.sh" 'load_homebrew' 'tmux child must reload Homebrew'
  assert_file_contains "$SCRIPTS_DIR/shared/install/shared-node-setup.sh" 'load_nvm' 'Node child must reload NVM'
  assert_file_contains "$SCRIPTS_DIR/mac/install/mac-software-setup.sh" 'load_homebrew' 'Mac software child must reload Homebrew'
  assert_file_contains "$SCRIPTS_DIR/mac/install/mac-system-settings.sh" '.machine-wallpaper-$color_key-rgb.png' 'Mac wallpaper filename must change with its color'
  assert_file_contains "$SCRIPTS_DIR/mac/install/mac-system-settings.sh" 'MACHINE_COLOR_HEX' 'Mac wallpaper must use the selected machine color'
  assert_file_contains "$SCRIPTS_DIR/mac/install/mac-system-settings.sh" 'pixelsWide: 1, pixelsHigh: 1' 'Mac wallpaper must write an exact solid-color pixel'
  assert_file_contains "$SCRIPTS_DIR/mac/install/mac-system-settings.sh" '[[ ! -s "$image_path" ]]' 'Mac wallpaper generation must reuse an existing color image'
  assert_file_contains "$SCRIPTS_DIR/mac/install/mac-system-settings.sh" "MACHINE_COLOR_HEX='#458588'" 'Mac blue must use the saturated Gruvbox shade'
  assert_file_contains "$SCRIPTS_DIR/mac/install/mac-system-settings.sh" 'NSGlassDiffusionSetting -int 0' 'Mac Liquid Glass style must be clear'
  assert_file_contains "$SCRIPTS_DIR/mac/install/mac-system-settings.sh" 'AppleReduceDesktopTinting -bool true' 'Mac wallpaper tinting must be disabled'
  assert_file_contains "$SCRIPTS_DIR/mac/install/mac-system-settings.sh" 'wvous-br-modifier -int 131072' 'Mac Mission Control hot corner must require Shift'
  assert_file_contains "$SCRIPTS_DIR/mac/install/mac-system-settings.sh" 'EnableTiledWindowMargins -bool true' 'Mac tiled and filled windows must leave margins'
  assert_file_contains "$SCRIPTS_DIR/mac/install/mac-system-settings.sh" 'show-process-indicators -bool false' 'Mac Dock open application indicators must be disabled'
  assert_file_contains "$SCRIPTS_DIR/mac/install/mac-system-settings.sh" 'AppleIconAppearanceTheme -string ClearLight' 'Mac icon and widget style must be clear light'
  assert_file_contains "$SCRIPTS_DIR/mac-install.sh" 'run_with_node' 'Mac power setup must reload Node'
  assert_file_contains "$SCRIPTS_DIR/shared/install/shared-zsh-setup.sh" 'run_privileged chsh' 'Linux shell change must use sudo'
  assert_file_contains "$SCRIPTS_DIR/shared/install/shared-tmux-setup.sh" 'bin/install_plugins' 'tmux plugins must be installed'
  bad_lib_count="$(find "$SCRIPTS_DIR/lib" -type f ! -name 'lib-*' | wc -l | tr -d ' ')"
  assert_equal 0 "$bad_lib_count" 'every Bash library filename must start with lib-'
  pass 'one Brewfile and fresh environment loading'
}

main() {
  test_machine_routing
  test_safe_links
  test_clipboard_routing
  test_fresh_process_runner
  test_mac_entrypoint
  test_mac_power_mode
  test_linux_entrypoint
  test_machine_name_menu_bar
  test_fake_tailscale_lifecycle
  test_tailscale_contract
  test_one_brewfile_and_environment_loading
  printf 'Passed %d installer tests.\n' "$PASS_COUNT"
}

main "$@"
