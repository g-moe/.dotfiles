#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../../lib"

. "$LIB_DIR/lib-get-linux-or-mac.sh"
. "$LIB_DIR/lib-logging.sh"
. "$LIB_DIR/lib-utils.sh"

enable_install_error_trap

mac() {
  local binary_dir="$HOME/.local/bin"
  local binary_path="$binary_dir/machine-name-menu-bar"
  local agent_dir="$HOME/Library/LaunchAgents"
  local agent_path="$agent_dir/local.machine-name-menu-bar.plist"
  local service="gui/$(id -u)/local.machine-name-menu-bar"

  mkdir -p "$binary_dir" "$agent_dir"
  xcrun swiftc -o "$binary_path" - <<'SWIFT'
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
item.button?.title = CommandLine.arguments[1]

app.run()
SWIFT

  cat >"$agent_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>local.machine-name-menu-bar</string>
  <key>ProgramArguments</key>
  <array>
    <string>$binary_path</string>
    <string>$MACHINE_NAME</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
EOF

  launchctl bootout "$service" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$(id -u)" "$agent_path"
  log_info "Machine name added to the Mac menu bar: $MACHINE_NAME"
}

linux() {
  local uuid='machine-name@local'
  local extension_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"
  local enabled_extensions
  local shell_version

  if ! has_command gnome-shell || ! has_command gnome-extensions || ! has_command gsettings; then
    log_info 'Skipped machine name in the top bar; GNOME is not installed.'
    return
  fi

  shell_version="$(gnome-shell --version | awk '{print $3}' | cut -d. -f1)"
  mkdir -p "$extension_dir"

  cat >"$extension_dir/metadata.json" <<EOF
{
  "uuid": "$uuid",
  "name": "Machine Name",
  "description": "Shows the machine name in the top bar.",
  "shell-version": ["$shell_version"]
}
EOF

  cat >"$extension_dir/extension.js" <<EOF
import GObject from 'gi://GObject';
import St from 'gi://St';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';

const Indicator = GObject.registerClass(
class Indicator extends PanelMenu.Button {
  _init() {
    super._init(0.0, 'Machine Name');
    this.add_child(new St.Label({text: '$MACHINE_NAME'}));
  }
});

export default class MachineNameExtension extends Extension {
  enable() {
    this._indicator = new Indicator();
    Main.panel.addToStatusArea(this.uuid, this._indicator);
  }

  disable() {
    this._indicator.destroy();
    this._indicator = null;
  }
}
EOF

  enabled_extensions="$(gsettings get org.gnome.shell enabled-extensions)"
  if [[ "$enabled_extensions" != *"'$uuid'"* ]]; then
    case "$enabled_extensions" in
      '[]' | '@as []') enabled_extensions="['$uuid']" ;;
      *) enabled_extensions="${enabled_extensions%]}, '$uuid']" ;;
    esac
    gsettings set org.gnome.shell enabled-extensions "$enabled_extensions"
  fi

  gnome-extensions enable "$uuid" >/dev/null 2>&1 || true
  log_info "Machine name added to the GNOME top bar: $MACHINE_NAME"
  log_info 'Log out and back in if the machine name is not visible yet.'
}

dispatch_linux_or_mac
