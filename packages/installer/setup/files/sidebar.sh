#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_file_sidebar() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_mac_sidebar() {
  local folders="$1"
  local pid seconds=0

  /usr/bin/osascript -l JavaScript "$STRATEGY_DIR/finder-sidebar.js" \
    "$HOME" "$ROOT_DIR" "$HOME/code" /Applications \
    "$folders/Desktop" "$folders/Documents" "$folders/Downloads" \
    "$HOME/Pictures" "$HOME/Movies" &
  pid=$!
  while silent kill -0 "$pid"; do
    if ((seconds >= 10)); then
      silent kill "$pid" || true
      silent wait "$pid" || true
      return 1
    fi
    sleep 1
    seconds=$((seconds + 1))
  done
  wait "$pid" || return 1

  # The files phase must reload favorites without waiting for the system phase.
  silent killall sharedfilelistd || true
  silent killall Finder || true
}

_check_icloud_folder() {
  local local_folder="$1" icloud_folder="$2"

  [[ -d "$icloud_folder" ]] ||
    die "Missing iCloud folder: $icloud_folder. Set up these folders in iCloud Drive, then rerun the files phase."
  [[ "$local_folder" -ef "$icloud_folder" ]] && return 0
  [[ ! -L "$local_folder" ]] || die "Existing symlink points elsewhere: $local_folder"
  [[ ! -e "$local_folder" || -d "$local_folder" ]] || die "Expected a folder: $local_folder"
  if [[ -d "$local_folder" && ( -e "$local_folder-local" || -L "$local_folder-local" ) ]]; then
    die "Backup already exists: $local_folder-local"
  fi
}

_link_icloud_folder() {
  local local_folder="$1" icloud_folder="$2" backup="$1-local"
  local permissions protected=0 moved=0
  local delete_acl='group:everyone deny delete'

  _check_icloud_folder "$local_folder" "$icloud_folder"
  [[ "$local_folder" -ef "$icloud_folder" ]] && return 0

  # Keep local files outside iCloud and remove only the ACL that blocks renaming.
  if [[ -d "$local_folder" ]]; then
    permissions="$(LC_ALL=C ls -lde "$local_folder")" || die "Could not inspect $local_folder"
    if grep -Eq "^[[:space:]]*[0-9]+: $delete_acl$" <<<"$permissions"; then
      chmod -a "$delete_acl" "$local_folder" || die "Could not unlock $local_folder for renaming."
      protected=1
    fi
    if ! mv -n "$local_folder" "$backup" || [[ -e "$local_folder" ]]; then
      if ((protected)); then
        chmod +a "$delete_acl" "$local_folder" || die "Could not restore the rename protection on $local_folder."
      fi
      die "Could not move $local_folder to $backup."
    fi
    moved=1
  fi

  # Do not follow a link if another run has already created it.
  if ln -sn "$icloud_folder" "$local_folder" && [[ "$local_folder" -ef "$icloud_folder" ]]; then
    return 0
  fi

  # Restore the old folder if linking failed and the original path is still free.
  if ((moved)) && [[ ! -e "$local_folder" && ! -L "$local_folder" ]]; then
    mv -n "$backup" "$local_folder" && [[ ! -e "$backup" ]] ||
      die "Could not restore $local_folder. Its files are in $backup."
    if ((protected)); then
      chmod +a "$delete_acl" "$local_folder" || die "Could not restore the rename protection on $local_folder."
    fi
  fi
  die "Could not link $local_folder to $icloud_folder."
}

mac() {
  local choice folder folders="$HOME"
  local icloud_folders=(Desktop Documents Downloads)

  choice="$(ask_choice 'Finder sidebar:' Skip 'With iCloud' 'Default (local folders)')"
  case "$choice" in
    0) return 0 ;;
    1)
      folders="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
      for folder in "${icloud_folders[@]}"; do
        _check_icloud_folder "$HOME/$folder" "$folders/$folder"
      done
      ;;
    2) ;;
    *) die "Unsupported Finder sidebar choice: $choice" ;;
  esac

  mkdir -p "$HOME/code"
  if ! _mac_sidebar "$folders"; then
    log 'Finder sidebar setup needs Full Disk Access for this terminal app.'
    /usr/bin/open 'x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles' || true
    if [[ ! -t 0 ]]; then
      die 'Grant Full Disk Access, then run the files phase again.'
    fi

    printf 'Grant Full Disk Access, then press Enter to retry: ' >/dev/tty
    read -r </dev/tty
    _mac_sidebar "$folders" || die 'Finder sidebar setup still does not have Full Disk Access.'
  fi

  if [[ "$choice" == 1 ]]; then
    for folder in "${icloud_folders[@]}"; do
      _link_icloud_folder "$HOME/$folder" "$folders/$folder"
    done
  fi
}

linux() {
  local bookmarks directory target
  mkdir -p "$HOME/code" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
  bookmarks="file://$HOME Home
file://$ROOT_DIR .dotfiles
file://$HOME/code code
file://$HOME/Desktop Desktop
file://$HOME/Documents Documents
file://$HOME/Downloads Downloads
file://$HOME/Pictures Pictures
file://$HOME/Videos Videos"
  for directory in gtk-3.0 gtk-4.0; do
    target="$HOME/.config/$directory/bookmarks"
    printf '%s\n' "$bookmarks" >"$target"
  done
}

configure_file_sidebar "$1"
