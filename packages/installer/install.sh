#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

. "$SCRIPT_DIR/lib/lib.sh"

usage='Use: bash packages/installer/install.sh [--apps|--development|--appearance|--input|--desktop|--files|--access|--system|--all|--git|--skills|--theme]'

validate_root() {
  [[ "$ROOT_DIR" == "$HOME/.dotfiles" ]] ||
    die "Clone this repo to $HOME/.dotfiles before running the installer."
}

run_strategy() {
  local label="$1"
  local path="$2"

  run_step "$label" bash "$SCRIPT_DIR/setup/$path" "$OS"
}

install_apps() {
  run_strategy 'Prepare application installer' apps/prepare.sh
  run_strategy 'Cloudflare Tunnel' apps/cloudflared.sh
  run_strategy 'Fastfetch' apps/fastfetch.sh
  run_strategy 'GitHub CLI' apps/github-cli.sh
  run_strategy 'Neovim' apps/neovim.sh
  run_strategy 'tmux' apps/tmux.sh
  run_strategy 'File association tool' apps/file-associations.sh
  run_strategy 'ImageMagick' apps/imagemagick.sh
  run_strategy 'CleanShot X' apps/screenshot.sh
  run_strategy 'Ghostty' apps/ghostty.sh
  run_strategy 'JetBrains Mono' apps/jetbrains-mono.sh
  run_strategy 'Keyboard remapper' apps/keyboard-remapper.sh
  run_strategy 'Display controls' apps/display-controls.sh
  run_strategy 'Application launcher' apps/launcher.sh
  run_strategy 'Phone integration' apps/phone-integration.sh
  run_strategy 'Passwords and keys' apps/passwords.sh
  run_strategy 'Notes' apps/notes.sh
  run_strategy 'VSCodium' apps/vscodium.sh
  run_strategy 'Codex' apps/codex.sh
  run_strategy 'Docker' apps/docker.sh
  run_strategy 'Virtual machines' apps/virtual-machines.sh
  run_strategy 'Chrome' apps/chrome.sh
  run_strategy 'Firefox' apps/firefox.sh
  run_strategy 'Keyboard pointer control' apps/keyboard-pointer.sh
  run_strategy 'Voice dictation' apps/voice-dictation.sh
  run_strategy 'Temperature monitor' apps/temperature-monitor.sh
  run_strategy 'System monitor' apps/system-monitor.sh
  run_strategy 'OpenCode' apps/opencode.sh
  run_strategy 'Zsh' apps/zsh.sh
  run_strategy 'Clipboard tools' apps/clipboard.sh
  run_strategy 'Tailscale' apps/tailscale.sh
  run_strategy 'NordVPN' apps/nordvpn.sh
}

install_git() {
  run_strategy 'Git, Git LFS, and GitHub login' development/git.sh
}

install_skills() {
  run_strategy 'Agent skills' skills.sh
}

# Generate/install app theme packs (VS Code, Ghostty, nvim, …) from packages/theming/.
install_theme() {
  if [[ "$OS" == mac ]]; then
    load_homebrew || die 'Run --apps before --theme so Homebrew applications are available.'
  fi
  activate_repo_node "$ROOT_DIR" || die 'Run --development before --theme so Node.js is available.'
  run_step 'Custom themes' bash -c 'cd "$1" && npx tsx packages/theming/create/controller.ts' bash "$ROOT_DIR"
}

install_development() {
  install_git
  run_strategy 'Node.js 24' development/node.sh
  run_strategy 'Zsh' development/zsh.sh
  run_strategy 'tmux configuration' development/tmux.sh
  run_strategy 'VSCodium settings' development/vscodium-settings.sh
  run_strategy 'VSCodium extensions' development/vscodium-extensions.sh
  install_skills
}

configure_appearance() {
  run_strategy 'Wallpaper' appearance/wallpaper.sh
  run_strategy 'Screen saver' appearance/screensaver.sh
  run_strategy 'Theme' appearance/theme.sh
  run_strategy 'Icons' appearance/icons.sh
}

configure_input() {
  run_strategy 'Pointer' input/pointer.sh
  run_strategy 'Touchpad' input/touchpad.sh
  run_strategy 'Keyboard' input/keyboard.sh
  run_strategy 'Keyboard remapping' input/remapping.sh
}

configure_desktop() {
  run_strategy 'Workspaces' desktop/workspaces.sh
  run_strategy 'Desktop items' desktop/items.sh
  run_strategy 'Desktop widgets' desktop/widgets.sh
  run_strategy 'Windows' desktop/windows.sh
  run_strategy 'Dock' desktop/dock.sh
  run_strategy 'Top bar' desktop/top-bar.sh
  run_strategy 'Machine name display' desktop/machine-name.sh
}

configure_files() {
  run_strategy 'Default applications' files/default-applications.sh
  run_strategy 'File associations' files/associations.sh
  run_strategy 'File browser preferences' files/preferences.sh
  run_strategy 'File browser sidebar' files/sidebar.sh
}

configure_access() {
  run_strategy 'Handoff' access/handoff.sh
  run_strategy 'Apple Intelligence' access/apple-intelligence.sh
  run_strategy 'Voice assistant' access/voice-assistant.sh
  run_strategy 'Headless access' access/headless.sh
  run_strategy 'SSH' access/ssh.sh
  run_strategy 'VNC' access/vnc.sh
}

configure_system() {
  run_strategy 'Software updates' system/updates.sh
  run_strategy 'Power' system/power.sh
  run_strategy 'Refresh the desktop' system/restart-ui.sh
}

run_phase() {
  case "$1" in
    apps) install_apps ;;
    development) install_development ;;
    appearance) configure_appearance ;;
    input) configure_input ;;
    desktop) configure_desktop ;;
    files) configure_files ;;
    access) configure_access ;;
    system) configure_system ;;
    all)
      install_apps
      install_development
      configure_appearance
      configure_input
      configure_desktop
      configure_files
      configure_access
      configure_system
      ;;
    *) die "$usage" ;;
  esac
}

# Map one CLI arg to a mode. Phases also accept the bare name (apps) for older calls.
parse_mode() {
  case "$1" in
    --git) printf 'git\n' ;;
    --skills) printf 'skills\n' ;;
    --theme) printf 'theme\n' ;;
    --apps | apps) printf 'apps\n' ;;    
    --development | development) printf 'development\n' ;;
    --appearance | appearance) printf 'appearance\n' ;;
    --input | input) printf 'input\n' ;;
    --desktop | desktop) printf 'desktop\n' ;;
    --files | files) printf 'files\n' ;;
    --access | access) printf 'access\n' ;;
    --system | system) printf 'system\n' ;;
    --all | all) printf 'all\n' ;;
    *) die "$usage" ;;
  esac
}

main() {
  local mode

  [[ "$#" -le 1 ]] || die "$usage"
  if (($# == 0)); then
    mode=all
  else
    mode="$(parse_mode "$1")"
  fi

  detect_os
  run_step 'Check dotfiles location' validate_root
  run_step 'Check this machine' validate_os
  run_step 'Check your user' validate_user

  case "$mode" in
    git)
      install_git
      ;;
    skills)
      install_skills
      ;;
    theme)
      install_theme
      ;;
    *)
      run_strategy 'Machine name and color' identity.sh
      run_phase "$mode"
      ;;
  esac

  log_section 'Done'
  log "$OS $mode setup is complete."
}

main "$@"
