# macOS path_helper runs after .zshenv; keep its paths but restore selected NVM first.
if [[ -n "${NVM_BIN:-}" ]]; then
  typeset -U path
  path=("$NVM_BIN" $path)
fi
