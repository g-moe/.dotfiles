#!/usr/bin/env bash
set -euo pipefail

STRATEGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(cd "$STRATEGY_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$INSTALLER_DIR/../.." && pwd)"
. "$INSTALLER_DIR/lib/lib.sh"

configure_machine_name_display() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() {
  local agent_path binary_path domain name service

  name="$(machine_field "$ROOT_DIR/machine.json" name)"
  binary_path="$HOME/.local/bin/machine-name-menu-bar"
  agent_path="$HOME/Library/LaunchAgents/local.machine-name-menu-bar.plist"
  domain="gui/$(id -u)"
  service="$domain/local.machine-name-menu-bar"
  mkdir -p "$(dirname "$binary_path")" "$(dirname "$agent_path")"
  xcrun swiftc -o "$binary_path" - <<'SWIFT'
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
item.button?.title = CommandLine.arguments[1]
app.run()
SWIFT
  printf '%s\n' "$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>local.machine-name-menu-bar</string>
  <key>ProgramArguments</key>
  <array><string>$binary_path</string><string>machine:$name</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict>
</plist>
EOF
)" >"$agent_path"
  if silent launchctl print "$service"; then
    silent launchctl bootout "$service"
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      silent launchctl print "$service" || break
      sleep 0.1
    done
    if silent launchctl print "$service"; then
      die 'The old machine-name menu item did not stop.'
    fi
  fi
  launchctl bootstrap "$domain" "$agent_path"
}

linux() {
  log 'Xfce panel machine-name display is not part of this install.'
  return 0
}

configure_machine_name_display "$1"
