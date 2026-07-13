#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/lib/lib-install.sh"

configure_power() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

_mode() {
  local choice
  choice="$(choose 'Power mode:' Skip Normal Server)"
  case "$choice" in
    0) printf 'skip\n' ;;
    1) printf 'normal\n' ;;
    2) printf 'server\n' ;;
  esac
}

mac() {
  local autorestart capabilities mode power_mode standby
  local -a settings

  mode="$(_mode)"
  [[ "$mode" != skip ]] || return 0
  capabilities="$(pmset -g cap)"
  power_mode=1
  standby=1
  autorestart=0
  if [[ "$mode" == server && "$capabilities" == *highpowermode* ]]; then
    power_mode=2
  fi
  if [[ "$mode" == server ]]; then
    standby=0
    autorestart=1
  fi
  settings=(
    sleep 0
    displaysleep 0
    disksleep 10
    womp 1
    powernap 1
    tcpkeepalive 1
    standby "$standby"
    ttyskeepawake 1
    hibernatemode 3
    lessbright 1
    powermode "$power_mode"
    autorestart "$autorestart"
  )
  if [[ "$capabilities" == *lowpowermode* ]]; then
    settings+=(lowpowermode 0)
  fi
  sudo pmset -a "${settings[@]}"
}

linux() {
  local mode profile

  mode="$(_mode)"
  [[ "$mode" != skip ]] || return 0
  profile=balanced
  [[ "$mode" == normal ]] || profile=performance
  gsettings set org.gnome.settings-daemon.plugins.power idle-dim false
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type nothing
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
  if has powerprofilesctl && powerprofilesctl list | grep -Fq "$profile:"; then
    sudo powerprofilesctl set "$profile"
  fi
  install_root_file /etc/systemd/logind.conf.d/60-machine-power.conf \
    '[Login]
IdleAction=ignore
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore'
}

configure_power "$1"
