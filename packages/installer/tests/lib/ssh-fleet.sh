#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/test.sh"

tool="$BASH_LIB_DIR/bin/shared-ssh-fleet.sh"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT
mkdir -p "$temporary_dir/bin" "$temporary_dir/home/.ssh"

# Fake tmux records every call and hands out pane ids %0, %1, ... in order
cat >"$temporary_dir/bin/tmux" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TEST_COMMANDS"
case "$1" in
  has-session) exit "${TEST_HAS_SESSION:-1}" ;;
  new-session | split-window)
    count="$(cat "$TEST_PANES" 2>/dev/null || printf '0')"
    printf '%%%s\n' "$count"
    printf '%s\n' "$((count + 1))" >"$TEST_PANES"
    ;;
  display-message) printf '40\n' ;;
  list-panes) printf '%b' "${TEST_PANE_LIST:-}" ;;
esac
EOF

# Fake git reports this machine's uncommitted changes and unpushed commits
cat >"$temporary_dir/bin/git" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TEST_COMMANDS"
case "$3" in
  status) printf '%b' "${TEST_LOCAL_CHANGES:-}" ;;
  rev-list) printf '%s\n' "${TEST_AHEAD:-0}" ;;
esac
EOF
chmod +x "$temporary_dir/bin/tmux" "$temporary_dir/bin/git"

cat >"$temporary_dir/home/.ssh/config" <<'EOF'
Host linux
  HostName 10.0.0.2
Host mini
  HostName 10.0.0.3
Host cloud-gg
  HostName 10.0.0.4
Host windows
  HostName 10.0.0.5
EOF

export TEST_COMMANDS="$temporary_dir/commands"
export TEST_PANES="$temporary_dir/panes"

run_fleet() {
  : >"$TEST_COMMANDS"
  rm -f "$TEST_PANES"
  env -u TMUX PATH="$temporary_dir/bin:$PATH" HOME="$temporary_dir/home" \
    SSH_FLEET_ENV_FILE="$temporary_dir/.env" bash "$tool" "$@" >/dev/null 2>&1
}

expect_command() {
  grep -Fxq -- "$1" "$TEST_COMMANDS" || fail "$2"
}

# First run builds the layout: right half, then top/bottom, then alternate rows
printf 'SSH_FLEET_ALIASES="linux mini cloud-gg windows" # four hosts\n' >"$temporary_dir/.env"
run_fleet || fail 'ssh-fleet must build a new session'
expect_command "has-session -t =ssh-fleet" 'ssh-fleet must check for its session'
grep -q '^new-session -d -s ssh-fleet ' "$TEST_COMMANDS" || fail 'ssh-fleet must create the session detached'
grep -q '^split-window -h -l 50% -t %0 ' "$TEST_COMMANDS" || fail 'alias 1 must take the right half'
grep -q '^split-window -v -l 50% -t %1 ' "$TEST_COMMANDS" || fail 'alias 2 must split the right half into top and bottom'
grep -q '^split-window -h -l 50% -t %1 ' "$TEST_COMMANDS" || fail 'alias 3 must split the top row'
grep -q '^split-window -h -l 50% -t %2 ' "$TEST_COMMANDS" || fail 'alias 4 must split the bottom row'
expect_command 'send-keys -t %1 ssh linux Enter' 'alias 1 must connect in the top-right pane'
expect_command 'send-keys -t %2 ssh mini Enter' 'alias 2 must connect in the bottom-right pane'
expect_command 'send-keys -t %3 ssh cloud-gg Enter' 'alias 3 must connect in the new top pane'
expect_command 'send-keys -t %4 ssh windows Enter' 'alias 4 must connect in the new bottom pane'
expect_command 'resize-pane -t %1 -x 40' 'the top row must be resized to equal widths'
expect_command 'resize-pane -t %2 -x 40' 'the bottom row must be resized to equal widths'
expect_command 'select-pane -t %0' 'the local pane must have focus'
expect_command 'attach-session -t =ssh-fleet' 'ssh-fleet must attach outside tmux'

# An existing session is joined as it is
TEST_HAS_SESSION=0 run_fleet || fail 'ssh-fleet must join an existing session'
grep -q '^new-session' "$TEST_COMMANDS" && fail 'ssh-fleet must not rebuild an existing session'
expect_command 'attach-session -t =ssh-fleet' 'ssh-fleet must attach to the existing session'

# --restart kills the session, then builds it again
TEST_HAS_SESSION=0 run_fleet --restart || true
expect_command 'kill-session -t =ssh-fleet' '--restart must kill the existing session'

# --install types the command into every pane of an existing session, then joins
install_command='cd "$HOME/.dotfiles" && git fetch origin && git stash push --include-untracked -m "ssh-fleet $(date +%Y-%m-%dT%H:%M:%S)" && git checkout -B main origin/main && git reset --hard origin/main && npm run install:agents'
export TEST_PANE_LIST='%0\n%1\n%2\n'
TEST_HAS_SESSION=0 run_fleet --install || fail 'ssh-fleet --install must run on an existing session'
expect_command "send-keys -t %0 $install_command Enter" '--install must run on this machine'
expect_command "send-keys -t %1 $install_command Enter" '--install must run in the first host pane'
expect_command "send-keys -t %2 $install_command Enter" '--install must run in the second host pane'
expect_command 'attach-session -t =ssh-fleet' '--install must still join the session'

# --install stops before touching any session when this machine has local work
TEST_LOCAL_CHANGES=' M zsh/.zshrc\n' run_fleet --install && fail '--install accepted uncommitted changes'
grep -q '^\(new-session\|send-keys\|has-session\)' "$TEST_COMMANDS" && fail '--install must not touch tmux with uncommitted changes'

TEST_AHEAD=2 TEST_HAS_SESSION=0 run_fleet --install && fail '--install accepted unpushed commits'
grep -q '^send-keys' "$TEST_COMMANDS" && fail '--install must not type into panes with unpushed commits'
unset TEST_PANE_LIST

# Inside tmux, ssh-fleet switches instead of attaching
: >"$TEST_COMMANDS"
TEST_HAS_SESSION=0 TMUX=/tmp/tmux-test PATH="$temporary_dir/bin:$PATH" HOME="$temporary_dir/home" \
  SSH_FLEET_ENV_FILE="$temporary_dir/.env" bash "$tool" >/dev/null 2>&1 || fail 'ssh-fleet must switch inside tmux'
expect_command 'switch-client -t =ssh-fleet' 'ssh-fleet must switch clients inside tmux'

# A bad .env stops before creating anything
printf 'SSH_FLEET_ALIASES="linux nowhere"\n' >"$temporary_dir/.env"
run_fleet && fail 'ssh-fleet accepted an alias missing from ~/.ssh/config'
grep -q '^new-session' "$TEST_COMMANDS" && fail 'ssh-fleet must not create a session for an unknown alias'

printf 'OTHER=1\n' >"$temporary_dir/.env"
run_fleet && fail 'ssh-fleet accepted a .env without SSH_FLEET_ALIASES'

run_fleet work && fail 'ssh-fleet accepted a session name argument'

printf 'ssh-fleet tests passed.\n'
