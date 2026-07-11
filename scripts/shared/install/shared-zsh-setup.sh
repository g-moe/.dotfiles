#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
LIB_DIR="$SCRIPTS_DIR/lib"
TOOLS_DIR="$SCRIPTS_DIR/shared/tools"

. "$LIB_DIR/lib-logging.sh"
. "$LIB_DIR/lib-utils.sh"
. "$LIB_DIR/lib-get-linux-or-mac.sh"
. "$LIB_DIR/lib-runtime.sh"

enable_install_error_trap

install_oh_my_zsh() {
  local oh_my_zsh_dir="$1"

  if [[ ! -d "$oh_my_zsh_dir" ]]; then
    log_info 'Cloning Oh My Zsh...'
    git clone https://github.com/ohmyzsh/ohmyzsh.git "$oh_my_zsh_dir"
    return
  fi

  if [[ -s "$oh_my_zsh_dir/oh-my-zsh.sh" ]]; then
    log_info 'Oh My Zsh already installed.'
    return
  fi

  local temp_dir
  temp_dir="$(mktemp -d)"
  log_info 'Repairing incomplete Oh My Zsh installation...'
  git clone https://github.com/ohmyzsh/ohmyzsh.git "$temp_dir/oh-my-zsh"
  cp -R "$temp_dir/oh-my-zsh/." "$oh_my_zsh_dir/"
  rm -rf "$temp_dir"
}

install_zsh_plugin() {
  local plugin_dir="$1"
  local plugin_name="$2"
  local repository="$3"
  local expected_file="$4"
  local target="$plugin_dir/$plugin_name"

  if [[ -f "$target/$expected_file" ]]; then
    log_info "$plugin_name already installed."
    return
  fi

  if [[ -L "$target" || ( -e "$target" && ! -d "$target" ) ]]; then
    log_error "Refusing to repair unexpected plugin path: $target"
    return 1
  fi

  if [[ -d "$target" ]]; then
    local temp_dir
    temp_dir="$(mktemp -d)"
    log_info "Repairing incomplete $plugin_name installation..."
    git clone "$repository" "$temp_dir/$plugin_name"
    cp -R "$temp_dir/$plugin_name/." "$target/"
    rm -rf "$temp_dir"
  else
    log_info "Installing $plugin_name..."
    git clone "$repository" "$target"
  fi

  if [[ ! -f "$target/$expected_file" ]]; then
    log_error "$plugin_name installation is missing $expected_file."
    return 1
  fi
}

install_zsh_themes() {
  local theme_dir="$1"
  local dark_source="$ROOT_DIR/custom-themes/output/oh-my-zsh/gtheme-dark.zsh-theme"
  local light_source="$ROOT_DIR/custom-themes/output/oh-my-zsh/gtheme-light.zsh-theme"

  if [[ ! -f "$dark_source" || ! -f "$light_source" ]]; then
    log_error 'Custom Zsh theme sources are missing from the repository.'
    return 1
  fi

  mkdir -p "$theme_dir"
  cp "$dark_source" "$theme_dir/gtheme-dark.zsh-theme"
  cp "$light_source" "$theme_dir/gtheme-light.zsh-theme"
  log_info 'Installed custom Zsh themes.'
}

register_shell() {
  local current_user
  local zsh_path="$1"
  current_user="${USER:-$(id -un)}"

  if [[ -f /etc/shells ]] && ! /usr/bin/grep -qxF "$zsh_path" /etc/shells; then
    run_privileged /bin/sh -c 'printf "%s\n" "$1" >> /etc/shells' _ "$zsh_path"
    log_info "Added $zsh_path to /etc/shells."
  fi

  if [[ "${SHELL:-}" == "$zsh_path" ]]; then
    log_info "Default shell already set to $zsh_path."
    return
  fi

  if run_privileged chsh -s "$zsh_path" "$current_user"; then
    log_info "Set default shell to $zsh_path."
  else
    log_error "Could not set the default shell. Run: sudo chsh -s '$zsh_path' '$current_user'"
    return 1
  fi
}

configure_zsh() {
  local zsh_path="$1"
  local home_dir="${HOME:-}"
  local oh_my_zsh_dir="$home_dir/.oh-my-zsh"
  local plugin_dir="$oh_my_zsh_dir/custom/plugins"
  local theme_dir="$oh_my_zsh_dir/custom/themes"

  if [[ -z "$home_dir" ]]; then
    log_error 'HOME is not set; cannot configure Zsh.'
    return 1
  fi

  if [[ ! -x "$zsh_path" ]]; then
    log_error "Zsh was not installed at the expected path: $zsh_path"
    return 1
  fi

  if ! has_command git; then
    log_error 'git is required for Zsh setup.'
    return 1
  fi

  install_oh_my_zsh "$oh_my_zsh_dir"
  mkdir -p "$plugin_dir"
  install_zsh_plugin "$plugin_dir" zsh-autosuggestions \
    https://github.com/zsh-users/zsh-autosuggestions.git \
    zsh-autosuggestions.zsh
  install_zsh_plugin "$plugin_dir" zsh-syntax-highlighting \
    https://github.com/zsh-users/zsh-syntax-highlighting.git \
    zsh-syntax-highlighting.zsh
  install_zsh_themes "$theme_dir"

  safe_link "$ROOT_DIR/.zshrc" "$home_dir/.zshrc"
  safe_link "$TOOLS_DIR/shared-copy-to-clipboard.sh" \
    "$home_dir/.local/bin/copy-to-clipboard"
  register_shell "$zsh_path"
}

mac() {
  configure_zsh /bin/zsh
}

linux() {
  if ! load_homebrew; then
    log_error 'Homebrew is required before Linux Zsh setup.'
    return 1
  fi

  configure_zsh "$(brew --prefix zsh)/bin/zsh"
}

main() {
  if [[ "$(id -u)" -eq 0 ]]; then
    log_error 'Do not run Zsh setup as root.'
    exit 1
  fi

  dispatch_linux_or_mac "$@"
}

main "$@"
