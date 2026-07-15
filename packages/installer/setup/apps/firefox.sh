#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_firefox() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  brew_cask firefox
  [[ -d /Applications/Firefox.app ]] || die 'Firefox is missing after installation.'
}

linux() {
  local installed_version=''

  install_apt_key \
    https://packages.mozilla.org/apt/repo-signing-key.gpg \
    /etc/apt/keyrings/packages.mozilla.org.asc \
    plain \
    35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3
  install_root_file /etc/apt/sources.list.d/mozilla.sources "$(cat <<'EOF'
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF
)"
  install_root_file /etc/apt/preferences.d/mozilla "$(cat <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF
)"
  sudo apt-get update

  if has snap && silent snap list firefox; then
    sudo snap remove --purge firefox
  fi
  if installed_version="$(dpkg-query -W -f='${Version}' firefox 2>/dev/null)" &&
    [[ "$installed_version" == *snap* ]]; then
    sudo apt-get remove -y firefox
  fi
  apt_install firefox
  has firefox || die 'Firefox is missing after installation.'
}

install_firefox "$1"
