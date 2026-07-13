#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

configure_zsh() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_clone_once() {
  local repository="$1"
  local target="$2"

  [[ -d "$target/.git" ]] && return
  [[ ! -e "$target" ]] || die "Refusing to replace $target"
  git clone "$repository" "$target"
}

_configure() {
  local shell_path="$1"
  local custom="$HOME/.oh-my-zsh/custom"

  _clone_once https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
  _clone_once https://github.com/zsh-users/zsh-autosuggestions.git \
    "$custom/plugins/zsh-autosuggestions"
  _clone_once https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$custom/plugins/zsh-syntax-highlighting"
  mkdir -p "$custom/themes" "$HOME/.local/bin"
  cp "$ROOT_DIR/custom-themes/output/oh-my-zsh/gtheme-dark.zsh-theme" "$custom/themes/"
  cp "$ROOT_DIR/custom-themes/output/oh-my-zsh/gtheme-light.zsh-theme" "$custom/themes/"
  link_config "$ROOT_DIR/.zshrc" "$HOME/.zshrc"
  link_config "$ROOT_DIR/scripts/shared/tools/shared-copy-to-clipboard.sh" \
    "$HOME/.local/bin/copy-to-clipboard"
  grep -qxF "$shell_path" /etc/shells ||
    printf '%s\n' "$shell_path" | sudo tee -a /etc/shells >/dev/null
  [[ "${SHELL:-}" == "$shell_path" ]] ||
    sudo chsh -s "$shell_path" "${USER:-$(id -un)}"
}

mac() {
  _configure /bin/zsh
}

linux() {
  _configure /usr/bin/zsh
}

configure_zsh "$1"
