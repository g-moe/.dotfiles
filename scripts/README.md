# Machine installer

Run this from a clean macOS machine or an Ubuntu 26.04 amd64 machine:

```bash
bash scripts/install.sh
```

This is the only install command. It finds the operating system and then runs the same ordered list of app and setting files.

During VM testing, one part can be run at a time without keeping a second list of steps:

```bash
bash scripts/install.sh apps
bash scripts/install.sh desktop
```

The available parts are `apps`, `development`, `appearance`, `input`, `desktop`, `files`, `access`, and `system`. With no part given, the installer runs all of them in that order.

Each file owns one thing and keeps both operating systems together. For example:

```bash
install_vscodium() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  brew_cask vscodium
}

linux() {
  apt_install codium
}

install_vscodium "$1"
```

The files are split by purpose:

- `setup/apps` installs one app per file.
- `setup/development` sets up Node, Zsh, tmux, VSCodium, and agent Skills.
- `setup/appearance` changes the wallpaper, screen saver, and theme.
- `setup/input` changes the pointer, touchpad, keyboard, and key remapping.
- `setup/desktop` changes workspaces, desktop items, windows, the Dock, and the top bar.
- `setup/files` changes file associations and Finder or Files settings.
- `setup/access` changes Handoff, assistants, SSH, and screen sharing.
- `setup/system` changes updates and power.

macOS uses Homebrew. Ubuntu uses APT when the app is available there. A vendor package is used only when Ubuntu does not carry the app.

Ubuntu ships Firefox as a Snap. The Firefox strategy removes that copy and installs Mozilla's APT package so future Firefox updates stay under APT.

The installer is for a clean machine. It has no move-old-files steps and no support for an older installer layout.

See [TESTING.md](TESTING.md) for the clean-machine checks.
