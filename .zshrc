# Path to your oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="gtheme-dark"

# Plugins
plugins=(
  git
  docker
  kubectl
  node
  npm
  yarn
  python
  pip
  golang
  rust
  zsh-autosuggestions
  zsh-syntax-highlighting
  history-substring-search
  colored-man-pages
  extract
  web-search
)

# Platform detection
is_macos=false
[[ "$OSTYPE" == darwin* ]] && is_macos=true

# Homebrew
if [[ "$is_macos" == true && -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ "$is_macos" == true && -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
elif [[ "$is_macos" == false && -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# User-installed commands
export PATH="$HOME/.local/bin:$PATH"

# Prevent reload from expanding global aliases while Oh My Zsh parses plugins.
(( ${+galiases[yank]} )) && unalias 'yank'

# macOS-only plugins
if [[ "$is_macos" == true ]]; then
  plugins+=(brew macos copypath copyfile)
fi

# Enable grep color when the installed grep supports --color
if command grep --help 2>&1 | command grep -q -- '--color'; then
  alias grep='grep --color=auto'
fi

# Oh My Zsh
if [[ -s "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

# History configuration
HISTSIZE=50000
SAVEHIST=50000
HISTFILE="$HOME/.zsh_history"
setopt SHARE_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt EXTENDED_HISTORY

# Key bindings for history search
if (( ${+widgets[history-substring-search-up]} )); then
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
fi
bindkey '^R' history-incremental-search-backward

# Print out alias
alias aliases='grep "^alias " ~/.zshrc'

# Reload zshrc
alias reload='source ~/.zshrc'

# List out directories with `cd` change directory
unalias cd 2>/dev/null
cd() {
  builtin cd "$@" && ls -a
}

# History
alias h='history'

# List configured SSH host aliases
alias ssh-hosts='awk '\''tolower($1)=="host" {for (i=2; i<=NF; i++) if ($i !~ /[*?]/) print $i}'\'' ~/.ssh/config'

# Walk through creating a new SSH host config
alias ssh-new='$HOME/.config/scripts/shared/tools/shared-ssh-new-host.sh'

# Copy to clipboard and print to terminal
if command -v copy-to-clipboard >/dev/null 2>&1; then
  alias -g yank='| tee /dev/tty | copy-to-clipboard'
fi

# Git stash including untracked files
alias gitstash='git stash -u'

# Git clean dry
alias gc-dry='git clean -nd'

# Git clean force
alias gc='git clean -fd'

# Support 256 color terminal
export TERM=xterm-256color

# Default editor (prefer nvim > vim > vi)
if command -v nvim >/dev/null 2>&1; then
  export EDITOR='nvim'
  export VISUAL='nvim'
elif command -v vim >/dev/null 2>&1; then
  export EDITOR='vim'
  export VISUAL='vim'
else
  export EDITOR='vi'
  export VISUAL='vi'
fi

# Github token from keychain or gh cli
if [[ "$is_macos" == true ]] && command -v security >/dev/null 2>&1; then
  token="$(security find-generic-password -s "GITHUB_TOKEN" -w 2>/dev/null || true)"
  [[ -n "$token" ]] && export GITHUB_TOKEN="$token"
elif [[ -z "${GITHUB_TOKEN:-}" ]] && command -v gh >/dev/null 2>&1; then
  token="$(gh auth token 2>/dev/null || true)"
  [[ -n "$token" ]] && export GITHUB_TOKEN="$token"
fi
unset token

# AWS
export AWS_PROFILE=tradester-test
export AWS_REGION=us-east-1

# NVM
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
if (( ${+functions[nvm]} )); then
  nvm use --silent default >/dev/null 2>&1 || true
  nvm_node="$(nvm which default 2>/dev/null || true)"
  if [[ -x "$nvm_node" ]]; then
    export PATH="$(dirname "$nvm_node"):$PATH"
    rehash
  fi
  unset nvm_node
fi

# opencode
if [[ -d "$HOME/.opencode/bin" ]]; then
  export PATH="$HOME/.opencode/bin:$PATH"
fi

# Added by LM Studio CLI (lms)
if [[ -d "$HOME/.lmstudio/bin" ]]; then
  export PATH="$PATH:$HOME/.lmstudio/bin"
fi
# End of LM Studio CLI section
