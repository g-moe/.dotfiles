# Load NVM and select the nearest project's version, or the default otherwise.
export NVM_DIR="$HOME/.nvm"

# Select Node for the current directory: the nearest .nvmrc walking up from
# $PWD, or the NVM default when no project declares one. Defined here so every
# shell has it; .zshrc reuses it on directory change. Pass --silent to switch
# without announcing it.
_use_node_version() {
  whence -w nvm >/dev/null 2>&1 || return 0

  local nvmrc target
  nvmrc="$(nvm_find_nvmrc 2>/dev/null)"
  if [[ -n "$nvmrc" ]]; then
    target="$(nvm version "$(<"$nvmrc")" 2>/dev/null)"
  else
    target="$(nvm version default 2>/dev/null)"
  fi

  [[ -n "$target" && "$target" != 'N/A' ]] || return 0
  [[ "$(nvm current)" == "$target" ]] && return 0

  if [[ "$1" == '--silent' ]]; then
    nvm use --silent "$target" >/dev/null 2>&1 || true
  else
    nvm use "$target"
  fi
}

if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  source "$NVM_DIR/nvm.sh" --no-use >/dev/null 2>&1
  _use_node_version --silent
fi
