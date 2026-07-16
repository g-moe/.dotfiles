#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_vnc() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  local choice state
  choice="$(ask_choice 'VNC:' Skip Disable Enable)"
  case "$choice" in
    0) return 0 ;;
    1)
      open 'x-apple.systempreferences:com.apple.Sharing-Settings.extension' || true
      printf 'Turn Screen Sharing off, then press Enter: ' >/dev/tty
      read -r </dev/tty
      state="$(sudo launchctl print-disabled system 2>/dev/null || true)"
      [[ "$state" == *'"com.apple.screensharing" => disabled'* ]] ||
        die 'Screen Sharing is still on.'
      ;;
    2)
      open 'x-apple.systempreferences:com.apple.Sharing-Settings.extension' || true
      printf 'Turn Screen Sharing on, then press Enter: ' >/dev/tty
      read -r </dev/tty
      state="$(sudo launchctl print-disabled system 2>/dev/null || true)"
      [[ "$state" == *'"com.apple.screensharing" => enabled'* ]] ||
        die 'Screen Sharing is still off.'
      sudo launchctl print system/com.apple.screensharing >/dev/null
      ;;
  esac
}

# Ubuntu builds gnome-remote-desktop with -Dvnc=false; detect a VNC-capable daemon.
linux_grd_has_vnc() {
  local daemon
  for daemon in /usr/libexec/gnome-remote-desktop-daemon \
    /usr/lib/*/gnome-remote-desktop/gnome-remote-desktop-daemon; do
    [[ -x "$daemon" ]] || continue
    ldd "$daemon" 2>/dev/null | grep -q libvncserver && return 0
  done
  return 1
}

# Enable deb-src so apt-get source / build-dep can fetch the Ubuntu package.
linux_enable_deb_src() {
  local file
  for file in /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list; do
    [[ -f "$file" ]] || continue
    if [[ "$file" == *.sources ]]; then
      sudo sed -i 's/^Types: deb$/Types: deb deb-src/' "$file"
    else
      sudo sed -i 's/^# deb-src/deb-src/' "$file"
    fi
  done
  sudo apt-get update
}

# Rebuild the Ubuntu package with -Dvnc=true and hold it so apt does not revert.
linux_install_grd_vnc() {
  local work src_dir deb

  if linux_grd_has_vnc; then
    return 0
  fi

  log 'Ubuntu GRD is RDP-only; rebuilding gnome-remote-desktop with VNC...'
  apt_install dpkg-dev debhelper meson ninja-build pkg-config fakeroot \
    libvncserver-dev
  linux_enable_deb_src
  sudo apt-get build-dep -y gnome-remote-desktop
  apt_install libvncserver-dev

  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  (
    cd "$work"
    apt-get source gnome-remote-desktop
    src_dir="$(find . -maxdepth 1 -type d -name 'gnome-remote-desktop-*' | head -n 1)"
    [[ -n "$src_dir" ]] || die 'Could not download gnome-remote-desktop source.'
    cd "$src_dir"

    grep -q -- '-Dvnc=true' debian/rules ||
      sed -i 's/-Dfdk_aac=false \\/-Dfdk_aac=false \\\n\t\t-Dvnc=true \\/' debian/rules
    grep -q libvncserver-dev debian/control ||
      sed -i 's/^Build-Depends:/Build-Depends:\n               libvncserver-dev,/' debian/control

    DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -us -uc -b
  )

  deb="$(find "$work" -maxdepth 1 -type f -name 'gnome-remote-desktop_*.deb' | head -n 1)"
  [[ -n "$deb" ]] || die 'VNC-enabled gnome-remote-desktop package was not built.'
  sudo dpkg -i "$deb"
  sudo apt-get install -f -y
  sudo apt-mark hold gnome-remote-desktop
  rm -rf "$work"
  trap - EXIT
  linux_grd_has_vnc || die 'Rebuilt gnome-remote-desktop still lacks VNC.'
}

linux() {
  local choice password
  choice="$(ask_choice 'VNC:' Skip Disable Enable)"
  case "$choice" in
    0) return 0 ;;
    1)
      if has grdctl; then
        silent grdctl vnc disable || true
        silent grdctl --headless vnc disable || true
        silent grdctl rdp disable || true
        silent grdctl --headless rdp disable || true
      fi
      silent systemctl --user disable --now gnome-remote-desktop.service || true
      silent systemctl --user disable --now gnome-remote-desktop-headless.service || true
      ;;
    2)
      linux_install_grd_vnc
      password="$(read_secret 'VNC password')"
      # LibVNCServer passwords are capped at 8 characters.
      [[ "${#password}" -le 8 ]] || die 'VNC password must be 8 characters or fewer.'
      grdctl vnc set-auth-method password
      printf '%s\n' "$password" | grdctl vnc set-password
      grdctl vnc disable-view-only
      grdctl vnc enable
      silent grdctl rdp disable || true
      systemctl --user enable --now gnome-remote-desktop.service
      systemctl --user is-active --quiet gnome-remote-desktop.service ||
        die 'GNOME Remote Desktop did not start.'
      ;;
  esac
}

configure_vnc "$1"
