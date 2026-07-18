#!/usr/bin/env bash

# Downloads and package installation shared by macOS and Debian setup files.

# Write root-owned file contents atomically through a temporary file.
# Usage: install_root_file /etc/apt/sources.list.d/app.list "$content"
install_root_file() {
  local path="$1"
  local content="$2"
  local temporary_file

  temporary_file="$(mktemp)"
  printf '%s\n' "$content" >"$temporary_file"
  sudo install -D -m 0644 "$temporary_file" "$path"
  rm -f "$temporary_file"
}

# Download an APT signing key and install it under /usr/share/keyrings.
# format is plain or dearmor. Optional fingerprint must match when provided.
# Usage: install_apt_key "$url" /usr/share/keyrings/app.gpg dearmor "$fingerprint"
install_apt_key() {
  local url="$1"
  local path="$2"
  local format="${3:-plain}"
  local fingerprint="${4:-}"
  local actual raw_file output_file

  raw_file="$(mktemp)"
  output_file="$(mktemp)"
  curl -fsSL "$url" -o "$raw_file"

  if [[ -n "$fingerprint" ]]; then
    actual="$(gpg --batch --quiet --show-keys --with-colons "$raw_file" |
      awk -F: '$1 == "fpr" { print $10; exit }')"
    [[ "$actual" == "$fingerprint" ]] || die "Signing key did not match for $url"
  fi

  case "$format" in
    plain) cp "$raw_file" "$output_file" ;;
    dearmor) gpg --batch --yes --dearmor --output "$output_file" "$raw_file" ;;
    *) die "Unknown key format: $format" ;;
  esac

  sudo install -D -m 0644 "$output_file" "$path"
  rm -f "$raw_file" "$output_file"
}

# Download the latest GitHub release asset matching a regex and verify its digest.
# Prints the temporary file path.
# Usage: package="$(download_github_asset owner/repo '\.deb$' .deb)"
download_github_asset() {
  local repository="$1"
  local pattern="$2"
  local suffix="$3"
  local asset digest file metadata url

  metadata="$(curl -fsSL "https://api.github.com/repos/$repository/releases/latest" |
    jq -r --arg pattern "$pattern" \
      '.assets[] | select(.name | test($pattern; "i")) | [.browser_download_url, .digest] | @tsv' |
    head -n 1)"
  IFS=$'\t' read -r url digest <<<"$metadata"
  [[ -n "$url" && "$url" != null ]] || die "No $repository release matched $pattern"
  [[ "$digest" == sha256:* ]] || die "No checksum was published for $url"

  file="$(mktemp --suffix="$suffix")"
  curl -fL "$url" -o "$file"
  printf '%s  %s\n' "${digest#sha256:}" "$file" | sha256sum --check --status ||
    die "Checksum failed for $url"
  printf '%s\n' "$file"
}

# Download, verify, and extract a pinned GitHub source archive.
# Prints the extracted source directory.
# Usage: source_dir="$(extract_github_source_archive owner/repo "$commit" "$checksum" "$destination")"
extract_github_source_archive() {
  local repository="$1"
  local commit="$2"
  local checksum="$3"
  local destination="$4"
  local archive source_dir

  archive="$(mktemp)"
  if ! curl -fsSL "https://codeload.github.com/$repository/tar.gz/$commit" -o "$archive"; then
    rm -f "$archive"
    die "Could not download the $repository source archive."
  fi
  if ! printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check --status; then
    rm -f "$archive"
    die "$repository source archive checksum failed."
  fi
  mkdir -p "$destination"
  if ! tar -xzf "$archive" -C "$destination"; then
    rm -f "$archive"
    die "Could not extract the $repository source archive."
  fi
  rm -f "$archive"

  source_dir="$destination/${repository##*/}-$commit"
  [[ -d "$source_dir" ]] || die "Extracted source directory is missing: $source_dir"
  printf '%s\n' "$source_dir"
}

# Load Homebrew into PATH when it is already installed.
# Returns 1 when Homebrew is missing.
# Usage: load_homebrew || die 'Homebrew is not installed.'
load_homebrew() {
  local brew_bin=''

  export HOMEBREW_NO_ASK=1
  if has brew; then
    return
  fi
  case "$(uname -m)" in
    arm64) brew_bin=/opt/homebrew/bin/brew ;;
    x86_64) brew_bin=/usr/local/bin/brew ;;
    *) die "Unsupported Mac architecture: $(uname -m)" ;;
  esac
  [[ -x "$brew_bin" ]] || return 1
  eval "$("$brew_bin" shellenv)"
}

# Install Homebrew when needed, then load it.
# Usage: install_homebrew
install_homebrew() {
  if load_homebrew; then
    return
  fi
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  load_homebrew || die 'Homebrew did not become available.'
}

# Install one or more Homebrew formulas.
# Usage: brew_formula gh neovim
brew_formula() {
  load_homebrew || die 'Homebrew is not installed.'
  brew install --no-ask --formula "$@"
}

# Install one or more Homebrew casks.
# Usage: brew_cask ghostty
brew_cask() {
  load_homebrew || die 'Homebrew is not installed.'
  brew install --no-ask --cask "$@"
}

# Install one or more APT packages.
# Usage: apt_install curl jq
apt_install() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}
