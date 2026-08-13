# mactop

`mactop` monitors Apple Silicon CPU, GPU, memory, power, temperature, processes, and fans. It provides a terminal UI, menu bar item, overlay, headless output, and Prometheus metrics.

`packages/mac/mactop` in the private dotfiles repository is the canonical home for this independently maintained U.S. English version. The dotfiles installer builds this source directly and installs it at `~/.local/bin/mactop`.

The same package owns `config.json` and `com.dotfiles.mactop-menubar.plist`, which the installer links into the user configuration and LaunchAgents directories.

## Requirements

- Apple Silicon Mac
- macOS 12.3 or later
- Go 1.25.4 or later for local builds

Fan control has been tested on M1 and M4 Mac mini hardware and an M4 Max MacBook Pro. Validate manual fan control before relying on it on another model.

## Build

```sh
cd ~/.dotfiles/packages/mac/mactop
go build -o mactop .
```

## Run

```sh
./mactop                         # Terminal UI
./mactop --menubar               # Menu bar
./mactop --overlay               # Floating overlay
./mactop --headless --count 1    # One JSON sample
./mactop --headless -p 2112      # Prometheus metrics
```

Run `./mactop --help` for the current flags. Press `h` or `?` in the terminal UI for its controls.

## Fan control

Monitoring does not require root. Fan writes require the privileged helper or an explicit root command.

### Menu bar Settings

Start `mactop --menubar`, open **Settings**, and select **Fans**. Select **Install Helper** once, approve the administrator prompt, choose a mode, and select **Apply**:

- **Apple Default** restores automatic fan control and removes the saved manual policy.
- **Constant** applies one RPM value to every fan. The value must be inside the common hardware range reported by all detected fans.
- **Curve** maps the CPU P-core average temperature from each fan's hardware minimum to its hardware maximum. Start ramp defaults to 38 °C and maximum temperature defaults to 85 °C. Values must be 20–100 °C with at least a 5 °C gap.

The helper stores Constant and Curve settings in `/Library/Application Support/mactop/fan-control.json`. After a reboot or helper restart, it resets the fans to automatic mode, validates the saved policy and current hardware limits, and then restores the policy. Invalid settings leave the fans in Apple Default.

Closing Settings or restarting the menu process does not stop the helper. The helper restores automatic mode on a normal shutdown, policy error, invalid sensor value, or failed SMC check. `SIGKILL` and power loss cannot run cleanup.

Recovery and diagnostic commands:

```sh
mactop --fan-policy-dry-run      # Calculate targets without SMC writes
sudo mactop --fan-control        # Use interactive fan controls in the TUI
sudo mactop --fan-policy         # Run the default 38–85 °C curve in foreground
sudo mactop --fan-reset          # Restore automatic control
```

Only one mactop fan-control process can own the SMC at a time.

mactop probes each fan's mode-key casing at runtime. It first tries the direct manual-mode write used by M1 and M4 Mac mini hardware. If Apple Silicon system mode rejects that write and the `Ftst` key is available, mactop enables force-test mode and retries for up to 10 seconds. This unlock is required on the tested M4 Max MacBook Pro and typically takes several seconds. A cancellation, timeout, policy error, reset, or normal shutdown clears force-test mode and verifies that no fan remains in manual mode. Apple Silicon system mode `3` is a valid automatic state; older hardware usually reports automatic mode `0`.

## Menu bar

The **Menubar** Settings tab controls CPU, GPU, and RAM visibility and colors, plus status-item width and font size. Fan control stays in the **Fans** tab. mactop does not add a separate fan icon.

## Overlay

The overlay requires Screen Recording permission for FPS data:

1. Open **System Settings → Privacy & Security → Screen Recording**.
2. Enable the terminal that starts mactop.
3. Restart the terminal if macOS requests it.

Use `mactop --dump-fps` to check permission and display capture. Other overlay metrics continue to work without it.

## Configuration

| File   | With XDG variable                     | Fallback                |
| ------ | ------------------------------------- | ----------------------- |
| Config | `$XDG_CONFIG_HOME/mactop/config.json` | `~/.mactop/config.json` |
| Theme  | `$XDG_CONFIG_HOME/mactop/theme.json`  | `~/.mactop/theme.json`  |
| Log    | `$XDG_STATE_HOME/mactop/mactop.log`   | `~/.mactop/mactop.log`  |

XDG base paths must be absolute.

A minimal theme file is enough:

```json
{
	"foreground": "#9580FF",
	"background": "#22212C"
}
```

## Development

```sh
cd ~/.dotfiles
npm run test:mactop
```

Follow the root dotfiles repository instructions for branches, review, and installation.

## License

MIT. See [LICENSE](LICENSE) for the original and current copyright notices.
