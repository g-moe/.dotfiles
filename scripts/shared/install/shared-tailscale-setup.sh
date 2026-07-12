#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../../lib"

. "$LIB_DIR/lib-get-linux-or-mac.sh"
. "$LIB_DIR/lib-interactive.sh"
. "$LIB_DIR/lib-logging.sh"
. "$LIB_DIR/lib-runtime.sh"
. "$LIB_DIR/lib-utils.sh"

enable_install_error_trap

ARG_COUNT="$#"
ACTION="${1:-}"
CURRENT_USER="${USER:-$(id -un)}"
TAILSCALE_UP_TIMEOUT="${TAILSCALE_UP_TIMEOUT:-120s}"
LINUX_SERVICE_NAME='linux-tailscaled.service'
LINUX_SERVICE_PATH="/etc/systemd/system/$LINUX_SERVICE_NAME"
LINUX_HOMEBREW_SERVICE_NAME='homebrew.tailscale.service'
LINUX_TAILSCALED_BIN='/home/linuxbrew/.linuxbrew/opt/tailscale/bin/tailscaled'

ensure_homebrew() {
  if ! load_homebrew || ! has_command brew; then
    log_error 'Homebrew is required for Tailscale setup.'
    return 1
  fi
}

install_tailscale_formula() {
  if brew_has_formula tailscale; then
    log_info 'Tailscale CLI already installed.'
    return
  fi

  brew install --formula tailscale
}

mac_root_service_started() {
  local brew_bin
  brew_bin="$(command -v brew)"
  sudo "$brew_bin" services list 2>/dev/null |
    grep -Eq '^tailscale[[:space:]]+started([[:space:]]|$)'
}

start_mac_service() {
  local brew_bin
  brew_bin="$(command -v brew)"

  if mac_root_service_started; then
    log_info 'Tailscale system service already started.'
    return
  fi

  log_info 'Starting Tailscale system service...'
  sudo "$brew_bin" services start tailscale
}

install_mac_cli() {
  if brew_has_cask tailscale-app; then
    log_info 'Removing the Tailscale GUI app before installing the CLI service.'
    brew uninstall --cask tailscale-app
  fi

  install_tailscale_formula
  start_mac_service
  log_info "Run bash $SCRIPT_DIR/shared-tailscale-setup.sh configure to sign in and configure access."
}

install_mac_gui() {
  local brew_bin
  brew_bin="$(command -v brew)"

  if brew_has_formula tailscale; then
    sudo "$brew_bin" services stop tailscale >/dev/null 2>&1 || true
    brew uninstall tailscale
  fi

  if brew_has_cask tailscale-app; then
    log_info 'Tailscale GUI app already installed.'
    return
  fi

  brew install --cask tailscale-app
}

stop_linux_homebrew_services() {
  local brew_bin="$1"
  local user_services

  "$brew_bin" services stop tailscale >/dev/null 2>&1 || true
  sudo systemctl disable --now "$LINUX_HOMEBREW_SERVICE_NAME" >/dev/null 2>&1 || true

  if ! user_services="$("$brew_bin" services list 2>&1)"; then
    log_error "Could not inspect the user Homebrew services: $user_services"
    return 1
  fi

  if grep -Eq '^tailscale[[:space:]]+started([[:space:]]|$)' <<<"$user_services"; then
    log_error 'The user Homebrew Tailscale service is still active.'
    return 1
  fi
  if sudo systemctl is-active --quiet "$LINUX_HOMEBREW_SERVICE_NAME"; then
    log_error 'The system Homebrew Tailscale service is still active.'
    return 1
  fi
}

refuse_vendor_linux_service() {
  local installed_units

  if sudo systemctl is-active --quiet tailscaled.service; then
    log_error 'A vendor tailscaled.service is active. Remove it before using the Homebrew service.'
    return 1
  fi

  if ! installed_units="$(sudo systemctl list-unit-files --type=service --no-legend --no-pager 2>&1)"; then
    log_error "Could not inspect systemd services: $installed_units"
    return 1
  fi
  if grep -q '^tailscaled\.service' <<<"$installed_units"; then
    log_error 'A vendor tailscaled.service is installed. Remove it before using the Homebrew service.'
    return 1
  fi
}

install_linux_service() {
  local temporary_service

  if ! has_command systemctl; then
    log_error 'systemd is required to run Tailscale on Linux.'
    return 1
  fi
  if [[ ! -x "$LINUX_TAILSCALED_BIN" ]]; then
    log_error "Tailscale daemon not found: $LINUX_TAILSCALED_BIN"
    return 1
  fi

  temporary_service="$(mktemp)"
  cat >"$temporary_service" <<EOF
[Unit]
Description=Tailscale node agent (Homebrew)
Documentation=https://tailscale.com/docs/
Wants=network-online.target
After=network-online.target

[Service]
Type=notify
NotifyAccess=all
User=root
Group=root
ExecStart=$LINUX_TAILSCALED_BIN --state=/var/lib/tailscale/tailscaled.state --socket=/run/tailscale/tailscaled.sock --port=41641
ExecStopPost=-$LINUX_TAILSCALED_BIN --cleanup
Restart=on-failure
RuntimeDirectory=tailscale
RuntimeDirectoryMode=0755
StateDirectory=tailscale
StateDirectoryMode=0700
CacheDirectory=tailscale
CacheDirectoryMode=0750

[Install]
WantedBy=multi-user.target
EOF

  if ! sudo cmp -s "$temporary_service" "$LINUX_SERVICE_PATH"; then
    sudo install -m 0644 "$temporary_service" "$LINUX_SERVICE_PATH"
  fi
  rm -f "$temporary_service"

  sudo systemctl daemon-reload
  sudo systemctl enable "$LINUX_SERVICE_NAME"
  sudo systemctl restart "$LINUX_SERVICE_NAME"
  if ! sudo systemctl is-active --quiet "$LINUX_SERVICE_NAME"; then
    log_error "$LINUX_SERVICE_NAME did not become active."
    return 1
  fi
  log_info "$LINUX_SERVICE_NAME is active."
}

install_linux_cli() {
  local brew_bin

  if ! has_command systemctl; then
    log_error 'systemd is required to run Tailscale on Linux.'
    return 1
  fi
  brew_bin="$(command -v brew)"

  stop_linux_homebrew_services "$brew_bin"
  refuse_vendor_linux_service
  install_tailscale_formula
  install_linux_service
  log_info "Run bash $SCRIPT_DIR/shared-tailscale-setup.sh configure to sign in and configure access."
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

ensure_tailscale_cli() {
  ensure_homebrew
  if ! has_command tailscale; then
    log_error 'The Tailscale CLI is not installed.'
    log_error "Run $0 install and choose CLI first."
    return 1
  fi
}

run_tailscale_up() {
  local mode="$1"
  local hostname_override="$2"
  local exit_node_choice="$3"
  local tailscale_bin
  local -a args=(up)

  tailscale_bin="$(command -v tailscale)"
  if [[ "$mode" == reset-* ]]; then
    args+=(--reset)
  fi
  if [[ -n "$CURRENT_USER" ]]; then
    args+=("--operator=$CURRENT_USER")
  fi
  if [[ "$mode" == *ssh ]]; then
    args+=(--ssh)
  fi
  if [[ -n "$hostname_override" ]]; then
    args+=("--hostname=$hostname_override")
  fi

  case "$exit_node_choice" in
    1) args+=(--advertise-exit-node=false) ;;
    2) args+=(--advertise-exit-node=true) ;;
  esac
  args+=("--timeout=$TAILSCALE_UP_TIMEOUT")

  log_info "Running sudo tailscale ${args[*]}"
  log_info "Waiting up to $TAILSCALE_UP_TIMEOUT for Tailscale login to complete."

  local status=0
  if sudo "$tailscale_bin" "${args[@]}"; then
    :
  else
    status=$?
  fi

  if [[ "$status" -ne 0 ]]; then
    log_error "tailscale up exited with code $status."
    log_error 'If browser login succeeded, check the machine with: tailscale status'
    return "$status"
  fi
}

show_status() {
  local tailscale_bin
  tailscale_bin="$(command -v tailscale)"
  "$tailscale_bin" status || sudo "$tailscale_bin" status
}

configure_cli() {
  local choice connection_host exit_node_choice hostname_override mode

  choice="$(interactive_select 'Configure Tailscale access:' \
    'Skip' \
    'Sign in only' \
    'Enable Tailscale SSH for remote shell access' \
    'Reset settings and enable Tailscale SSH')"

  case "$choice" in
    0)
      log_info 'Skipping Tailscale access setup.'
      return
      ;;
    1) mode=login ;;
    2) mode=ssh ;;
    3) mode=reset-ssh ;;
  esac

  hostname_override="$(read_optional_hostname)"
  exit_node_choice="$(read_exit_node_choice)"
  connection_host="${hostname_override:-$(hostname -s)}"

  if ! run_tailscale_up "$mode" "$hostname_override" "$exit_node_choice"; then
    show_status || true
    return 1
  fi

  show_status
  if [[ "$exit_node_choice" == '2' ]]; then
    log_info 'Exit node advertising requested. Approval may still be required in the Tailscale admin console.'
  fi
  if [[ "$mode" == *ssh ]]; then
    log_info "From another machine, connect with: tailscale ssh $CURRENT_USER@$connection_host"
  fi
}

install_mac() {
  local choice
  ensure_homebrew
  choice="$(interactive_select 'How do you want to install Tailscale?' \
    'Skip' \
    'CLI (system service)' \
    'App (GUI)')"

  case "$choice" in
    0) log_info 'Skipping Tailscale install.' ;;
    1) install_mac_cli ;;
    2) install_mac_gui ;;
  esac
}

install_linux() {
  local choice
  ensure_homebrew
  choice="$(interactive_select 'How do you want to install Tailscale?' \
    'Skip' \
    'CLI (system service)')"

  case "$choice" in
    0) log_info 'Skipping Tailscale install.' ;;
    1) install_linux_cli ;;
  esac
}

configure_mac() {
  ensure_tailscale_cli
  if brew_has_formula tailscale; then
    start_mac_service
  fi
  configure_cli
}

configure_linux() {
  ensure_tailscale_cli
  if ! sudo systemctl is-active --quiet "$LINUX_SERVICE_NAME"; then
    log_error "$LINUX_SERVICE_NAME is not active. Run the install mode first."
    return 1
  fi
  configure_cli
}

mac() {
  case "$ACTION" in
    install) install_mac ;;
    configure) configure_mac ;;
  esac
}

linux() {
  case "$ACTION" in
    install) install_linux ;;
    configure) configure_linux ;;
  esac
}

main() {
  if [[ "$ARG_COUNT" -ne 1 ]]; then
    printf 'Usage: %s {install|configure}\n' "$0" >&2
    return 2
  fi

  case "$ACTION" in
    install | configure) ;;
    *)
      printf 'Usage: %s {install|configure}\n' "$0" >&2
      return 2
      ;;
  esac

  dispatch_linux_or_mac
}

main
