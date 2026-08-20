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

### Sleep and wake policy

The helper treats a matched system sleep and wake as a pause while Constant or Curve control is selected. A wake event alone never starts manual control.

- On system sleep, the helper preserves the selected policy, cancels the active policy, and restores Apple Default. It does not wait for macOS to reclaim fan ownership and it does not run an `Ftst` retry during sleep.
- On wake, the helper waits for the stopped policy to finish cleanup and makes one resume attempt. The first SMC write still waits for the normal 500 ms metrics sample.
- If automatic-mode cleanup fails, the helper cancels the resume and records the cleanup failure.
- A new sleep cancels a queued or active resume. It keeps the selected policy for the next matched wake.
- After the first verified manual-mode sample, the resumed policy is normal manual control. A later error is a policy error, not a wake-resume error.
- A sensor error, target mismatch, or other non-sleep SMC error restores Apple Default and does not retry manual control automatically.
- A settings change, Apple Default, or shutdown cancels an older pending resume.

Power notifications are advisory. If macOS does not deliver a matched sleep and wake pair, the helper does not make an unprompted manual retry. The regular safety checks still restore Apple Default when manual control fails.

The privileged helper records fan-control transitions in `/Library/Logs/mactop/fan-control.log`. The log is root-owned, readable by local administrators, and keeps the current 512 KiB file plus one `.1` backup. A failure entry includes the selected policy, every fan's raw mode and RPM readback, expected RPM targets, the `Ftst` state, and the automatic-control restoration result. Sleep and wake handling adds `policy_suspend_requested`, `wake_resume_queued`, `wake_resume_cancelled`, `wake_resume_started`, `wake_resume_verified`, or `wake_resume_failed`. `policy_suspend_requested` means the helper cancelled manual writes; the following `apple_default_restored` confirms cleanup. `wake_resume_cancelled` records its reason. `wake_resume_failed` only means that the resume attempt failed before its first verified manual-mode sample. Use `tail -n 200 /Library/Logs/mactop/fan-control.log` after a fallback.

For a manual hardware check, apply Constant or Curve control, let the Mac sleep and wake normally, then inspect the log. Expect `policy_suspend_requested`, `apple_default_restored`, one `wake_resume_started`, and `wake_resume_verified`, or `wake_resume_cancelled` when the Mac sleeps again. Do not force system sleep as part of automated tests.

Recovery and diagnostic commands:

```sh
mactop --fan-policy-dry-run      # Calculate targets without SMC writes
sudo mactop --fan-control        # Use interactive fan controls in the TUI
sudo mactop --fan-policy         # Run the default 38–85 °C curve in foreground
sudo mactop --fan-reset          # Restore automatic control
```

Only one mactop fan-control process can own the SMC at a time.

mactop probes each fan's mode-key casing at runtime. It first tries the direct manual-mode write used by M1 and M4 Mac mini hardware. It verifies the mode and RPM target in the next policy sample, not by an immediate SMC read that can be stale. If Apple Silicon rejects the direct write and the `Ftst` key is available, mactop enables force-test mode and retries for up to 10 seconds. This unlock is required on the tested M4 Max MacBook Pro and typically takes several seconds. A cancellation, timeout, policy error, reset, or normal shutdown clears force-test mode and verifies that no fan remains in manual mode. Apple Silicon system mode `3` is a valid automatic state; older hardware usually reports automatic mode `0`.

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
