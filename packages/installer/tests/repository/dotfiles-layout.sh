#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

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
AGENTS.md
TODO.md
ghostty/config
images/icon.png
images/white.png
karabiner/karabiner.json
mactop/config.json
mactop/com.dotfiles.mactop-menubar.plist
nvim/init.lua
opencode/opencode.jsonc
packages/installer/install.sh
packages/installer/packages/retire.json
packages/installer/packages/retire.schema.json
packages/lib/bash/lib.sh
packages/lib/ts/.gitkeep
packages/mac
packages/theming/create/controller.ts
packages/vscode-ext/package.json
tmux/tmux.conf
package-lock.json
package.json
tsconfig.json
zsh/.zshrc
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
AGENTS.md
TODO.md
ghostty
images
karabiner
mactop
nvim
opencode
package-lock.json
package.json
packages
tmux
tsconfig.json
vscode
zsh
'
while IFS= read -r root; do
  [[ -z "$root" ]] && continue
  grep -qxF "$root" <<<"$allowed_roots" || fail "unexpected tracked root: $root"
done < <(
  git -C "$ROOT_DIR" ls-files | while IFS= read -r file; do
    [[ -e "$ROOT_DIR/$file" ]] && printf '%s\n' "${file%%/*}"
  done | sort -u
)

for path in \
  zed \
  opencode/opencode.png \
  opencode/package-lock.json \
  .zshrc \
  black.heic \
  icon.png \
  white.png \
  scripts \
  custom-themes \
  vscode-extensions; do
  [[ ! -e "$ROOT_DIR/$path" ]] || fail "old layout leftover is still present: $path"
done

for app in ghostty nvim opencode; do
  if grep -RFq "safe_symlink \"\$ROOT_DIR/$app\" \"\$HOME/.config/$app\"" \
    "$ROOT_DIR/packages/installer/setup"; then
    fail "$app links its whole source folder"
  fi
done

stale_references="$(grep -RInE \
  '(\$HOME/\.config/scripts|/Users/[^/]+/\.config|Open \.config|file://\$ROOT_DIR \.config|github\.com/[^ ]*/\.config)' \
  "$ROOT_DIR" \
  --exclude=package-lock.json \
  --exclude-dir=.git \
  --exclude-dir=.test-logs \
  --exclude-dir=node_modules || true)"
if [[ -n "$stale_references" ]]; then
  printf '%s\n' "$stale_references" >&2
  fail 'found stale repo references to .config'
fi

old_structure_references="$(grep -RInE \
  '(bash scripts/|scripts/(install\.sh|setup|tests|shared|lib|mac)/?|custom-themes/|vscode-extensions/)' \
  "$ROOT_DIR" \
  --exclude=dotfiles-layout.sh \
  --exclude=package-lock.json \
  --exclude-dir=.git \
  --exclude-dir=.test-logs \
  --exclude-dir=node_modules || true)"
if [[ -n "$old_structure_references" ]]; then
  printf '%s\n' "$old_structure_references" >&2
  fail 'found references to the old top-level structure'
fi

installer_dependencies="$(grep -RIn 'packages/installer' \
  "$ROOT_DIR/packages/lib" \
  "$ROOT_DIR/packages/mac" \
  "$ROOT_DIR/packages/theming" \
  "$ROOT_DIR/packages/vscode-ext" \
  --include='*.sh' \
  --include='*.ts' \
  --include='*.json' \
  --exclude=package-lock.json \
  --exclude-dir=node_modules || true)"
if [[ -n "$installer_dependencies" ]]; then
  printf '%s\n' "$installer_dependencies" >&2
  fail 'a lower package depends on packages/installer'
fi

library_dependencies="$(grep -RInE 'packages/(installer|mac|theming|vscode-ext)' \
  "$ROOT_DIR/packages/lib" \
  --include='*.sh' \
  --include='*.ts' \
  --include='*.json' || true)"
if [[ -n "$library_dependencies" ]]; then
  printf '%s\n' "$library_dependencies" >&2
  fail 'a standalone library depends on another package'
fi

if grep -IEqi 'ubuntu|gnome|gdm|gsettings' \
  "$ROOT_DIR/packages/installer/README.md" "$ROOT_DIR/packages/installer/TESTING.md"; then
  fail 'installer docs describe a removed Linux target'
fi

printf 'Dotfiles layout checks passed.\n'
