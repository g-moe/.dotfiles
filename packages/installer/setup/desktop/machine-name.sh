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
  local agent_path attempt binary_path name

  name="$(machine_field "$ROOT_DIR/machine.json" name)"
  binary_path="$HOME/.local/bin/machine-name-menu-bar"
  agent_path="$HOME/Library/LaunchAgents/local.machine-name-menu-bar.plist"
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
  silent launchctl bootout "gui/$(id -u)/local.machine-name-menu-bar" || true
  launchctl bootstrap "gui/$(id -u)" "$agent_path"
}

linux() {
  local extension_dir name shell_version uuid

  name="$(machine_field "$ROOT_DIR/machine.json" name)"
  uuid='machine-name@local'
  extension_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"
  shell_version="$(gnome-shell --version | awk '{print $3}' | cut -d. -f1)"
  mkdir -p "$extension_dir"
  printf '%s\n' "$(cat <<EOF
{
  "uuid": "$uuid",
  "name": "Machine Name",
  "description": "Shows the machine name in the top bar.",
  "shell-version": ["$shell_version"]
}
EOF
)" >"$extension_dir/metadata.json"
  printf '%s\n' "$(cat <<EOF
import GObject from 'gi://GObject';
import Clutter from 'gi://Clutter';
import St from 'gi://St';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';

const Indicator = GObject.registerClass(class Indicator extends PanelMenu.Button {
  _init() {
    super._init(0.0, 'Machine Name');
    this.add_child(new St.Label({
      text: 'machine:$name',
      y_expand: true,
      y_align: Clutter.ActorAlign.CENTER,
    }));
  }
});

export default class MachineNameExtension extends Extension {
  enable() {
    this._dateMenu = Main.panel.statusArea.dateMenu.container;
    this._dateParent = this._dateMenu.get_parent();
    this._dateIndex = this._dateParent.get_children().indexOf(this._dateMenu);
    this._dateParent.remove_child(this._dateMenu);
    Main.panel._rightBox.insert_child_at_index(this._dateMenu, 0);
    this._indicator = new Indicator();
    Main.panel.addToStatusArea(this.uuid, this._indicator, 0, 'right');
  }

  disable() {
    this._indicator.destroy();
    this._indicator = null;
    Main.panel._rightBox.remove_child(this._dateMenu);
    this._dateParent.insert_child_at_index(this._dateMenu, this._dateIndex);
    this._dateMenu = null;
    this._dateParent = null;
  }
}
EOF
)" >"$extension_dir/extension.js"
  enable_gnome_extension "$uuid"
}

configure_machine_name_display "$1"
