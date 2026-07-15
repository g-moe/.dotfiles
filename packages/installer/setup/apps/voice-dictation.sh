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
    amd64) install_openwhispr ;;
    arm64) install_whisper_cpp ;;
    *) die "No voice transcription tool is configured for $LINUX_ARCH" ;;
  esac
}

link_system_command() {
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

install_openwhispr() {
  local package

  package="$(download_github_asset OpenWhispr/openwhispr \
    'OpenWhispr-.*-linux-amd64\.deb$' .deb)"
  apt_install "$package"
  rm -f "$package"
  link_system_command /opt/OpenWhispr/open-whispr open-whispr
  has open-whispr || die 'OpenWhispr did not become available.'
}

install_whisper_cpp() {
  local archive source_dir temporary_dir

  log 'OpenWhispr has no Linux ARM build; installing whisper.cpp.'
  archive="$(download_github_asset ggml-org/whisper.cpp \
    '^whisper-bin-ubuntu-arm64\.tar\.gz$' .tar.gz)"
  temporary_dir="$(mktemp -d)"
  tar -xzf "$archive" -C "$temporary_dir"
  source_dir="$temporary_dir/whisper-bin-ubuntu-arm64"
  [[ -x "$source_dir/whisper-cli" ]] ||
    die 'The whisper.cpp archive did not contain whisper-cli.'
  sudo install -d -m 0755 /opt/whisper.cpp
  sudo cp -a --no-preserve=ownership "$source_dir/." /opt/whisper.cpp/
  link_system_command /opt/whisper.cpp/whisper-cli whisper-cli
  rm -rf "$temporary_dir" "$archive"
  has whisper-cli || die 'whisper.cpp did not become available.'
}

install_voice_dictation "$1"
