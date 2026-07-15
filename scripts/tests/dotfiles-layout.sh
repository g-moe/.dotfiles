#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[[ "$ROOT_DIR" == "$HOME/.dotfiles" ]] ||
  fail "repo must live at $HOME/.dotfiles, found $ROOT_DIR"

required_paths='
.agents
.gitignore
.nvmrc
.oxfmtrc.json
.vscode
.zshrc
AGENTS.md
TODO.md
black.heic
custom-themes
ghostty/config
karabiner/karabiner.json
nvim/init.lua
opencode/opencode.jsonc
scripts
tmux/tmux.conf
icon.png
package-lock.json
package.json
tsconfig.json
white.png
'
while IFS= read -r path; do
  [[ -z "$path" || -e "$ROOT_DIR/$path" ]] || fail "missing $path"
done <<<"$required_paths"

allowed_roots='
.agents
.gitignore
.nvmrc
.oxfmtrc.json
.vscode
.zshrc
AGENTS.md
TODO.md
black.heic
custom-themes
ghostty
icon.png
karabiner
nvim
opencode
package-lock.json
package.json
scripts
tmux
tsconfig.json
vscode
vscode-extensions
white.png
'
while IFS= read -r root; do
  [[ -z "$root" ]] && continue
  grep -qxF "$root" <<<"$allowed_roots" || fail "unexpected tracked root: $root"
done < <(
  git -C "$ROOT_DIR" ls-files | while IFS= read -r file; do
    [[ -e "$ROOT_DIR/$file" ]] && printf '%s\n' "${file%%/*}"
  done | sort -u
)

for path in zed opencode/opencode.png opencode/package-lock.json; do
  [[ ! -e "$ROOT_DIR/$path" ]] || fail "old config leftover is still present: $path"
done

for app in ghostty nvim opencode; do
  if grep -RFq "safe_symlink \"\$ROOT_DIR/$app\" \"\$HOME/.config/$app\"" \
    "$ROOT_DIR/scripts/setup"; then
    fail "$app links its whole source folder"
  fi
done

stale_references="$(git -C "$ROOT_DIR" grep -n -I -E \
  '(\$HOME/\.config/scripts|/Users/[^/]+/\.config|Open \.config|file://\$ROOT_DIR \.config|github\.com/[^ ]*/\.config)' \
  -- ':!**/package-lock.json' || true)"
if [[ -n "$stale_references" ]]; then
  printf '%s\n' "$stale_references" >&2
  fail 'found stale repo references to .config'
fi

printf 'Dotfiles layout checks passed.\n'
