#!/usr/bin/env bash
# Open or join a tmux session with this machine on the left half and one SSH pane per alias on the right.
# Aliases come from SSH_FLEET_ALIASES in the repository .env; each must be a Host in ~/.ssh/config.
# The right half fills top, bottom, then splits the top row, then the bottom row, and so on.
# Aliased as ssh-fleet in .zshrc.
#
# Joining an existing session types ssh again in any host pane that has dropped back to its local shell.
#
# Usage: ssh-fleet [--restart] [--install | --cmd=COMMAND]
#   --restart  Kill the ssh-fleet session first, then build it again.
#   --cmd      Type COMMAND into every pane (this machine and each host) and press Enter.
#              Pass it as --cmd=COMMAND or --cmd COMMAND, quoted as one argument.
#   --install  Stop before touching anything if this machine has uncommitted changes or unpushed commits.
#              Otherwise, in every pane (this machine and each host), stash local changes, reset ~/.dotfiles
#              to origin/main, and run npm run install:agents. The stash is a timestamped backup that is never
#              applied; with nothing to stash, git just carries on. Each pane asks for its own sudo password.
#
# Example .env line:
#   SSH_FLEET_ALIASES="linux mini cloud-gg"
#
# Example command:
#   ssh-fleet --cmd="aws sso login --profile my-profile --use-device-code --no-browser"

set -euo pipefail

SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do
  SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" == /* ]] || SOURCE="$SCRIPT_DIR/$SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$LIB_DIR/../../.." && pwd)"

. "$LIB_DIR/lib.sh"

SESSION='ssh-fleet'
ALIAS_OPTION='@ssh-fleet-alias'
ENV_FILE="${SSH_FLEET_ENV_FILE:-$ROOT_DIR/.env}"
SSH_CONFIG="${HOME:-}/.ssh/config"
ENV_EXAMPLE='SSH_FLEET_ALIASES="linux mini"'

# SSH aliases follow ssh-new's rule
ALIAS_PATTERN='^[A-Za-z0-9._-]+$'

# Typed into each host pane, so $(date ...) runs on the remote when the stash is made.
# Fleet machines always end on origin/main; their local edits stay in a stash that is never applied.
INSTALL_COMMAND='cd "$HOME/.dotfiles" && git fetch origin && git stash push --include-untracked -m "ssh-fleet $(date +%Y-%m-%dT%H:%M:%S)" && git checkout -B main origin/main && git reset --hard origin/main && npm run install:agents'

# A host pane running one of these has no ssh in front, so it is safe to type into
SHELL_PATTERN='^(zsh|bash|sh|fish)$'

# Size of a detached session when the terminal size can't be read
FALLBACK_COLUMNS=200
FALLBACK_LINES=50

USAGE='Usage: ssh-fleet [--restart] [--install | --cmd=COMMAND]
  --restart  Kill the ssh-fleet session first, then build it again.
  --install  Stop if this machine has local work; otherwise, in every pane, stash, reset ~/.dotfiles to origin/main, and run npm run install:agents.
  --cmd      Type COMMAND into every pane and press Enter, e.g. --cmd="aws sso login --profile my-profile".
  --help     Show this help.'

restart=0
install=0
command=''
aliases=()

read_args() {
  while (($# > 0)); do
    case "$1" in
      --restart) restart=1 ;;
      --install) install=1 ;;
      --cmd=*) command="${1#--cmd=}" ;;
      --cmd)
        (($# > 1)) || die 'Missing command after --cmd. Run ssh-fleet --help.'
        shift
        command="$1"
        ;;
      -h | --help)
        printf '%s\n' "$USAGE"
        exit 0
        ;;
      *) die "Unknown argument: $1. Run ssh-fleet --help." ;;
    esac
    shift
  done

  # Both type into the same panes, so the second would land as input to the first
  if ((install)) && [[ -n "$command" ]]; then
    die 'Pass --install or --cmd, not both.'
  fi
}

host_exists() {
  [[ -r "$SSH_CONFIG" ]] || return 1
  awk 'tolower($1)=="host" {for (i=2; i<=NF; i++) print $i}' "$SSH_CONFIG" | grep -Fxq "$1"
}

# Read SSH_FLEET_ALIASES from .env without running the file, then check every alias.
read_aliases() {
  local line value alias

  [[ -r "$ENV_FILE" ]] || die "No .env at $ENV_FILE. Add a line like: $ENV_EXAMPLE"

  line="$(grep -E '^[[:space:]]*(export[[:space:]]+)?SSH_FLEET_ALIASES=' "$ENV_FILE" | tail -n 1 || true)"
  [[ -n "$line" ]] || die "SSH_FLEET_ALIASES is not set in $ENV_FILE. Add a line like: $ENV_EXAMPLE"

  # Drop the name, a trailing comment, and quotes; aliases never contain them
  value="${line#*=}"
  value="${value%%#*}"
  value="${value//[\"\']/}"
  read -r -a aliases <<<"$value"
  ((${#aliases[@]} > 0)) || die "SSH_FLEET_ALIASES is empty in $ENV_FILE."

  for alias in "${aliases[@]}"; do
    [[ "$alias" =~ $ALIAS_PATTERN ]] || die "Not a valid SSH alias: $alias"
    host_exists "$alias" || die "No Host $alias in $SSH_CONFIG. Add it with ssh-new."
  done
}

# --install resets this machine too, so it must have no local work: nothing uncommitted and nothing unpushed.
check_local_work() {
  local changes ahead

  changes="$(git -C "$ROOT_DIR" status --porcelain)"
  [[ -z "$changes" ]] || die "$ROOT_DIR has uncommitted changes. Commit and push them before --install."$'\n'"$changes"

  ahead="$(git -C "$ROOT_DIR" rev-list --count '@{upstream}..HEAD' 2>/dev/null)" ||
    die "$ROOT_DIR has no upstream branch. Push it before --install."
  ((ahead == 0)) || die "$ROOT_DIR has $ahead unpushed commit(s). Push them before --install."
}

session_exists() {
  tmux has-session -t "=$SESSION" 2>/dev/null
}

split_pane() {
  local direction="$1"
  local target="$2"

  tmux split-window "$direction" -l 50% -t "$target" -c "$PWD" -P -F '#{pane_id}'
}

# Give every pane in one row of the right half the same width.
equalize_row() {
  local panes=("$@")
  local count="${#panes[@]}"
  local total=0 pane width index

  ((count > 1)) || return 0

  # Row width is the panes plus the one-column borders between them
  for pane in "${panes[@]}"; do
    total=$((total + $(tmux display-message -p -t "$pane" '#{pane_width}')))
  done
  total=$((total + count - 1))
  width=$(((total - (count - 1)) / count))

  # Resizing left to right takes the space from each pane's right neighbor
  for ((index = 0; index < count - 1; index++)); do
    tmux resize-pane -t "${panes[index]}" -x "$width"
  done
}

build_session() {
  local columns lines local_pane pane index
  local top_row=() bottom_row=()

  # Start with this machine's shell, sized to the current terminal so the halves land right
  columns="$(tput cols 2>/dev/null || printf '%s' "$FALLBACK_COLUMNS")"
  lines="$(tput lines 2>/dev/null || printf '%s' "$FALLBACK_LINES")"
  local_pane="$(tmux new-session -d -s "$SESSION" -c "$PWD" -x "$columns" -y "$lines" -P -F '#{pane_id}')"

  # Alias 1 takes the right half, alias 2 splits it into top and bottom.
  # After that, odd aliases split the top row's last pane and even aliases split the bottom row's last pane.
  for index in "${!aliases[@]}"; do
    if ((index == 0)); then
      pane="$(split_pane -h "$local_pane")"
      top_row+=("$pane")
    elif ((index == 1)); then
      pane="$(split_pane -v "${top_row[0]}")"
      bottom_row+=("$pane")
    elif ((index % 2 == 0)); then
      pane="$(split_pane -h "${top_row[${#top_row[@]} - 1]}")"
      top_row+=("$pane")
    else
      pane="$(split_pane -h "${bottom_row[${#bottom_row[@]} - 1]}")"
      bottom_row+=("$pane")
    fi

    # Tag the pane with its alias so a later join can reconnect it
    tmux set-option -p -t "$pane" "$ALIAS_OPTION" "${aliases[index]}"

    # Type the ssh command so the pane keeps a local shell after the connection ends
    tmux send-keys -t "$pane" "ssh ${aliases[index]}" Enter
  done

  equalize_row "${top_row[@]}"
  if ((${#bottom_row[@]} > 0)); then
    equalize_row "${bottom_row[@]}"
  fi
  tmux select-pane -t "$local_pane"
}

# Type ssh again in every host pane that sits at its local shell; this machine's pane has no alias and is left alone.
reconnect_panes() {
  local pane command alias

  while read -r pane command alias; do
    [[ -n "$alias" && "$command" =~ $SHELL_PATTERN ]] || continue
    tmux send-keys -t "$pane" "ssh $alias" Enter
  done < <(tmux list-panes -s -t "=$SESSION" -F "#{pane_id} #{pane_current_command} #{$ALIAS_OPTION}")
}

# Type a command into every pane, this machine's included, in a new or an existing session.
send_command() {
  local pane

  while read -r pane; do
    tmux send-keys -t "$pane" "$1" Enter
  done < <(tmux list-panes -s -t "=$SESSION" -F '#{pane_id}')
}

join_session() {
  # tmux can't attach from inside another session, so switch instead
  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "=$SESSION"
  else
    tmux attach-session -t "=$SESSION"
  fi
}

main() {
  read_args "$@"
  has tmux || die 'tmux was not found.'
  # A hard stop before any session or pane is touched
  if ((install)); then
    check_local_work
  fi

  if ((restart)) && session_exists; then
    tmux kill-session -t "=$SESSION"
  fi

  # Check every alias before creating anything, so a bad .env leaves no half-built session
  if session_exists; then
    reconnect_panes
  else
    read_aliases
    build_session
  fi

  if ((install)); then
    send_command "$INSTALL_COMMAND"
  elif [[ -n "$command" ]]; then
    send_command "$command"
  fi
  join_session
}

main "$@"
