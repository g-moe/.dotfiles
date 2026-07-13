# Clean install checks

All installer runs happen inside UTM. Do not run the installer or its tests on the main Mac.

## Machines

- macOS 26, clean Apple virtual machine
- Ubuntu 26.04 arm64, clean Apple Silicon virtual machine

## Rules

- Keep one stopped base machine after each operating system is installed and before the repo installer runs.
- Save one clean snapshot after the OS setup finishes. Restore that snapshot before every first-run test instead of rebuilding or cloning the VM.
- Copy or clone the repo inside the guest. Do not run from a read-only shared folder.
- Save the full terminal output for every run.
- After a first run passes, run the same installer a second time without cleaning the machine.
- A test only passes when the commands succeed and the result is checked in the desktop.
- Use `bash scripts/install.sh apps`, `desktop`, or another named part while fixing one part. Use the command with no part for final clean runs.

## Runs

| Run | macOS choice | Ubuntu choice | Status |
| --- | --- | --- | --- |
| App install A | Tailscale command-line service, NordVPN yes | Tailscale service, NordVPN yes | macOS earlier test passed twice; Ubuntu passed twice |
| App install B | Tailscale menu bar app, NordVPN no | Tailscale skipped, NordVPN no | Ubuntu passed; macOS pending |
| App install C | Tailscale skipped | Tailscale service | Ubuntu service choice covered by A; macOS pending |
| Desktop A | Dock hidden, small, bottom | Dock hidden, small, bottom | Ubuntu passed; macOS pending |
| Desktop B | Dock shown, large, left | Dock shown, large, left | Ubuntu passed; macOS pending |
| Desktop C | Dock unchanged, medium, right | Dock unchanged, medium, right | Ubuntu passed; macOS pending |
| Wallpaper A | Apply machine wallpaper | Apply machine wallpaper | Ubuntu passed; macOS pending |
| Wallpaper B | Keep current wallpaper | Keep current wallpaper | Ubuntu passed; macOS pending |
| Theme A | Apply dark theme and machine color | Apply dark theme and machine color | Ubuntu passed; macOS pending |
| Theme B | Keep current theme | Keep current theme | Ubuntu passed; macOS pending |
| Development | Node, Zsh, tmux, VSCodium, and Skills | Node, Zsh, tmux, VSCodium, and Skills | Ubuntu passed; macOS pending |
| Input | Pointer, touchpad, keyboard, and remapping | Pointer, touchpad, keyboard, and remapping | Ubuntu passed; macOS pending |
| Files | Associations, preferences, and sidebar | Associations, preferences, and sidebar | Ubuntu passed; macOS pending |
| Remote A | Enable remote access | Enable remote access | Ubuntu passed; macOS pending |
| Remote B | Skip remote access | Skip remote access | Ubuntu passed; macOS pending |
| Power A | Normal | Normal | Ubuntu passed; macOS pending |
| Power B | Server | Server | Ubuntu passed; macOS pending |
| Power C | Skip | Skip | Ubuntu passed; macOS pending |
| Full clean run | All normal choices | All normal choices | Ubuntu passed; macOS pending |
| Second run | Run again without a restore | Run again without a restore | Ubuntu full run passed twice; macOS full run pending |
| CPU support | Native Mac CPU | Ubuntu amd64 and arm64 paths | AMD64 official package checks and earlier live evidence passed; ARM64 live run passed |

## Results so far

- The Ubuntu 26.04 amd64 ISO matched Canonical's published SHA-256 checksum before the base machine was installed.
- Canonical's Ubuntu 26.04 arm64 desktop image matched its published `c2afd538d66fdd77377d03f1ed2ac76a34f1c116baecc9a8170d68f833121f57` SHA-256 checksum.
- `Clean Ubuntu 26.04 arm64` was created with native CPU virtualization, 6 cores, 6 GB of memory, a 128 GB disk, and the verified arm64 ISO. The old translated amd64 VM and ISO were removed.
- Ubuntu was installed once with user `m4` and computer name `m4-vm`. At the completed-install screen the VM was stopped, the ISO was removed, and the disk passed `qemu-img check` with no errors.
- The stopped pre-first-boot disk was saved as the verified internal snapshot `clean-base`. Its matching EFI state is saved as `efi_vars.clean-base.fd`; both are restored before every first-run test.
- Linux detects `LINUX_ARCH` once at startup. AMD64 keeps Google Chrome and OpenWhispr; arm64 uses Brave and whisper.cpp.
- Official arm64 package indexes contained Brave, VSCodium, Docker, Firefox, Cloudflared, Tailscale, and NordVPN. GitHub releases contained checksum-backed arm64 files for Codex, OpenCode, and whisper.cpp. Canonical's arm64 indexes contained every Ubuntu package named by the installer.
- `Clean macOS 26` is the one reusable Apple virtual machine. The OS install and clean snapshot are still pending.
- The strategy shape and Bash syntax check passed in the earlier disposable Mac test guest.
- The first app run passed with Tailscale's command-line service and NordVPN selected.
- `brew services list` showed Tailscale started as root from `/Library/LaunchDaemons/homebrew.mxcl.tailscale.plist`.
- VSCodium, Ghostty, Chrome, Firefox, OpenCode, and Codex opened successfully.
- Docker opened, then reported that nested virtualization is unavailable in the UTM macOS guest. Its install succeeded; its engine cannot be tested inside this guest.
- The same app run passed again without restoring the machine. Homebrew reported the apps current, and the running Tailscale service was kept running.
- The Ubuntu ARM64 app run passed, then the same app run passed again without a restore. Cloudflared, Fastfetch, GitHub CLI, Neovim, tmux, Ghostty, VSCodium, Codex, Docker, Brave, Firefox, whisper.cpp, Zsh, wl-copy, Tailscale, and NordVPN were checked from the guest.
- VSCodium, Brave, Firefox, and Ghostty opened in the Ubuntu desktop. OpenCode installed and its server and window code stayed running, but its Electron window did not become visible under UTM's Wayland display. The guest had free memory, no out-of-memory report, and no app crash. This remains a UTM display limit rather than an ARM64 package failure.
- The tracked wallpaper source is `white.png`. Ubuntu creates a 3840x2160 copy because UTM's virtual display rejected the 6016x3388 texture. The colored wallpaper appeared correctly in the guest. Both apply and skip choices passed.
- All three Ubuntu Dock choice sets passed. Development passed after removing the bad tmux entry that made the plugin manager try to install itself. Input and file settings passed.
- Ubuntu SSH stayed enabled and active. GNOME Remote Desktop now creates a local TLS certificate and starts the matching headless service. Both enable and skip choices passed.
- Normal, server, and skip power choices passed. The Linux power profile change uses `sudo`, and skip choices return success instead of stopping the installer.
- The reusable `test-ready` snapshot contains only the clean OS, guest agent, Expect, and the repo. The full clean run and its second run started from that snapshot.
- The Ubuntu full clean run passed with all normal choices. The exact same full command passed again without a restore.
- After reboot, the guest was still arm64 and named `m4-vm`. Docker, Tailscale, SSH, and GNOME Remote Desktop were enabled and active. The machine name, wallpaper, dark theme, bottom Dock, and eight skill links in each supported agent folder were also checked.
- Full logs from these runs, including both full passes and the post-reboot check, are saved on the host under `.test-logs/ubuntu-arm64-2026-07-13/`. The folder is ignored because test output is not source code.

## Desktop checks

- The required apps open: VSCodium, Ghostty, Chrome or Brave, Firefox, Docker, OpenCode, and the platform matches for the other Mac apps.
- JetBrains Mono is available.
- The Dock has the requested size, place, visibility, and app order.
- The machine name is in the menu bar. On Ubuntu it is the only item centered in the top bar and the clock is on the right.
- The machine-color wallpaper, dark theme, pointer, touchpad, keyboard, workspaces, desktop icons, and window settings match the chosen run.
- VSCodium owns the code and config file types.
- Finder or Files has the requested view, trash, and sidebar settings.
- SSH and screen sharing work from the other guest when enabled.
- Update and power settings match the chosen run.
- Skills appear in each supported agent folder.
