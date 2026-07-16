#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$APP_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

install_ghostty() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_configure() {
  local target="$HOME/.config/ghostty"

  safe_symlink "$ROOT_DIR/ghostty/config" "$target/config"
  safe_symlink "$ROOT_DIR/ghostty/themes/gtheme-dark" "$target/themes/gtheme-dark"
  safe_symlink "$ROOT_DIR/ghostty/themes/gtheme-light" "$target/themes/gtheme-light"
}

mac() {
  brew_cask ghostty
  _configure
  [[ -d /Applications/Ghostty.app ]] || die 'Ghostty is missing after installation.'
}

linux() {
  local appimage appimage_arch launcher

  case "$LINUX_ARCH" in
    amd64) appimage_arch=x86_64 ;;
    arm64) appimage_arch=aarch64 ;;
    *) die "No Ghostty build is configured for $LINUX_ARCH" ;;
  esac

  apt_install libfuse2t64
  appimage="$(download_github_asset pkgforge-dev/ghostty-appimage \
    "^Ghostty-.*-${appimage_arch}\\.AppImage$" .AppImage)"
  sudo install -D -m 0755 "$appimage" /opt/ghostty/ghostty.AppImage
  launcher="$(mktemp)"
  cat >"$launcher" <<'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail

# QEMU's virtual GPU reports OpenGL 3.3 even though Mesa can run Ghostty's
# required 4.3 path. Real hardware keeps its native Mesa version.
if [[ "$(systemd-detect-virt 2>/dev/null || true)" != none ]]; then
  export MESA_GL_VERSION_OVERRIDE="${MESA_GL_VERSION_OVERRIDE:-4.3}"
  export MESA_GLSL_VERSION_OVERRIDE="${MESA_GLSL_VERSION_OVERRIDE:-430}"
fi

exec /opt/ghostty/ghostty.AppImage "$@"
LAUNCHER
  sudo install -D -m 0755 "$launcher" /usr/local/bin/ghostty
  install_root_file /usr/local/share/applications/com.mitchellh.ghostty.desktop \
    '[Desktop Entry]
Type=Application
Name=Ghostty
Comment=Fast terminal emulator
Exec=/usr/local/bin/ghostty
Icon=utilities-terminal
Categories=System;TerminalEmulator;
Terminal=false'
  rm -f "$appimage" "$launcher"
  _configure
  has ghostty || die 'Ghostty is missing after installation.'
}

install_ghostty "$1"
