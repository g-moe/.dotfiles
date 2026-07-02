#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

. "$LIB_DIR/logging.sh"
. "$LIB_DIR/interactive.sh"
. "$LIB_DIR/utils.sh"

current_user="${USER:-$(id -un)}"
tailscale_up_timeout="${TAILSCALE_UP_TIMEOUT:-120s}"

ensure_tailscale_cli() {
  if has_command tailscale; then
    return
  fi

  log_error 'tailscale CLI not found.'
  log_error 'Install the Tailscale CLI first, then rerun this script.'
  exit 1
}

ensure_tailscale_service() {
  if ! has_command brew || ! brew_has_formula tailscale; then
    return
  fi

  if sudo brew services list | grep -Eq '^tailscale\s+started\b'; then
    log_info 'tailscale service already started.'
    return
  fi

  log_info 'Starting tailscale system service...'
  sudo brew services start tailscale
  log_info 'tailscale system service started.'
}

read_optional_hostname() {
  local hostname

  printf 'Tailscale hostname override (leave blank to use system hostname): ' >/dev/tty
  read -r hostname </dev/tty
  printf '%s\n' "$hostname"
}

read_exit_node_choice() {
  interactive_select 'Advertise this machine as a Tailscale exit node?' \
    'Skip (leave current setting)' \
    'No' \
    'Yes'
}

run_tailscale_up() {
  local mode="$1"
  local hostname="$2"
  local exit_node_choice="$3"
  local -a args=(up)

  if [[ "$mode" == reset-* ]]; then
    args+=(--reset)
  fi

  if [[ -n "$current_user" ]]; then
    args+=("--operator=$current_user")
  fi

  if [[ "$mode" == *ssh ]]; then
    args+=(--ssh)
  fi

  if [[ -n "$hostname" ]]; then
    args+=("--hostname=$hostname")
  fi

  case "$exit_node_choice" in
    1)
      args+=(--advertise-exit-node=false)
      ;;
    2)
      args+=(--advertise-exit-node=true)
      ;;
  esac

  args+=("--timeout=$tailscale_up_timeout")

  log_info "Running sudo tailscale ${args[*]}"
  log_info "Waiting up to $tailscale_up_timeout for Tailscale login to complete."
  log_info 'Browser success means auth worked; this command still waits for this machine to appear online.'

  set +e
  sudo tailscale "${args[@]}"
  local status=$?
  set -e

  if [[ "$status" -ne 0 ]]; then
    log_error "tailscale up exited with code $status."
    log_error 'If the browser said login succeeded, press Ctrl-C only if needed, then check: tailscale status'
    return "$status"
  fi
}

show_status() {
  tailscale status || sudo tailscale status
}

configure_access() {
  local mode="$1"
  local hostname_override
  local connection_host
  local exit_node_choice

  hostname_override="$(read_optional_hostname)"
  exit_node_choice="$(read_exit_node_choice)"
  connection_host="${hostname_override:-$(hostname -s)}"

  if ! run_tailscale_up "$mode" "$hostname_override" "$exit_node_choice"; then
    show_status || true
    return 1
  fi

  show_status

  if [[ "$exit_node_choice" == '2' ]]; then
    log_info 'Exit node advertising requested. You may still need to approve this machine as an exit node in the Tailscale admin console.'
  fi

  if [[ "$mode" == *ssh ]]; then
    log_info "From another machine, connect with: tailscale ssh $current_user@$connection_host"
  fi
}

main() {
  ensure_tailscale_cli
  ensure_tailscale_service


  local choice
  choice="$(interactive_select 'Configure Tailscale access:' \
    'Skip' \
    'Sign in only' \
    'Enable Tailscale SSH for remote shell access' \
    'Reset settings and enable Tailscale SSH')"

  case "$choice" in
    0)
      log_info 'Skipping Tailscale access setup.'
      ;;
    1)
      configure_access login
      ;;
    2)
      configure_access ssh
      ;;
    3)
      configure_access reset-ssh
      ;;
  esac
}

main "$@"
