# Load NVM and select the nearest project's version, or the default otherwise.
export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  source "$NVM_DIR/nvm.sh" --no-use >/dev/null 2>&1
  if [[ -n "$(nvm_find_nvmrc 2>/dev/null)" ]]; then
    nvm use --silent >/dev/null 2>&1 || true
  else
    nvm use --silent default >/dev/null 2>&1 || true
  fi
fi
