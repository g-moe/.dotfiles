#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_system_monitor() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  local agent_path binary_path build_dir config_path domain service source_dir
  local commit='e688d5778035b6d3eb30f2a8c8083cb1d429723d'
  local checksum='8fbf82eaaa4396bbf906dc3b66eb68408cca3d943d8ab7f2a9f01e1d845c140e'

  brew_formula go

  build_dir="$(mktemp -d)"
  source_dir="$(extract_github_source_archive g-moe/mactop "$commit" "$checksum" "$build_dir")"
  binary_path="$HOME/.local/bin/mactop"
  mkdir -p "$(dirname "$binary_path")"
  if ! (cd "$source_dir" && go build -o "$build_dir/mactop" main.go); then
    rm -rf "$build_dir"
    die 'Could not build the pinned mactop fork.'
  fi
  install -m 0755 "$build_dir/mactop" "$binary_path"
  rm -rf "$build_dir"

  config_path="$HOME/.mactop/config.json"
  agent_path="$HOME/Library/LaunchAgents/com.dotfiles.mactop-menubar.plist"
  safe_symlink_group mactop \
    "$ROOT_DIR/mactop/config.json" "$config_path" \
    "$ROOT_DIR/mactop/com.dotfiles.mactop-menubar.plist" "$agent_path"

  if [[ ! -L "$agent_path" || "$(readlink "$agent_path")" != "$ROOT_DIR/mactop/com.dotfiles.mactop-menubar.plist" ]]; then
    log 'Skipped mactop login startup because its LaunchAgent was not linked.'
    return 0
  fi

  domain="gui/$(id -u)"
  service="$domain/com.dotfiles.mactop-menubar"
  if silent launchctl print "$service"; then
    silent launchctl bootout "$service"
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      silent launchctl print "$service" || break
      sleep 0.1
    done
  fi
  launchctl bootstrap "$domain" "$agent_path"
}

linux() {
  apt_install xfce4-taskmanager
}

install_system_monitor "$1"
