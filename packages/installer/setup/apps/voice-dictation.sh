#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_voice_dictation() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  brew_cask voiceink
}

linux() {
  case "$LINUX_ARCH" in
    amd64) linux_install_openwhispr ;;
    arm64) linux_install_whisper_cpp ;;
    *) die "No voice transcription tool is configured for $LINUX_ARCH" ;;
  esac
}

linux_link_system_command() {
  local binary="$1"
  local target="/usr/local/bin/$2"

  [[ -x "$binary" ]] || die "$binary is not executable."
  if [[ -L "$target" ]]; then
    [[ "$(readlink "$target")" == "$binary" ]] ||
      die "Refusing to replace $target"
  elif [[ -e "$target" ]]; then
    die "Refusing to replace $target"
  else
    sudo ln -s "$binary" "$target"
  fi
}

linux_install_openwhispr() {
  local package

  package="$(download_github_asset OpenWhispr/openwhispr \
    'OpenWhispr-.*-linux-amd64\.deb$' .deb)"
  apt_install "$package"
  rm -f "$package"
  linux_link_system_command /opt/OpenWhispr/open-whispr open-whispr
  has open-whispr || die 'OpenWhispr did not become available.'
}

linux_install_whisper_cpp() {
  local archive source_dir temporary_dir

  log 'OpenWhispr has no Linux ARM build; installing whisper.cpp.'
  archive="$(download_github_asset ggml-org/whisper.cpp \
    '^whisper-bin-[^-]+-arm64\.tar\.gz$' .tar.gz)"
  temporary_dir="$(mktemp -d)"
  tar -xzf "$archive" -C "$temporary_dir"
  source_dir="$(find "$temporary_dir" -maxdepth 1 -type d -name 'whisper-bin-*-arm64' | head -n 1)"
  [[ -n "$source_dir" ]] || die 'The whisper.cpp archive directory is missing.'
  [[ -x "$source_dir/whisper-cli" ]] ||
    die 'The whisper.cpp archive did not contain whisper-cli.'
  sudo install -d -m 0755 /opt/whisper.cpp
  sudo cp -a --no-preserve=ownership "$source_dir/." /opt/whisper.cpp/
  linux_link_system_command /opt/whisper.cpp/whisper-cli whisper-cli
  rm -rf "$temporary_dir" "$archive"
  has whisper-cli || die 'whisper.cpp did not become available.'
}

install_voice_dictation "$1"
