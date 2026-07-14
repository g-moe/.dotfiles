# Clean install checks

All installer runs happen inside UTM. Do not run the installer or its tests on the main Mac.

## Machines

- macOS 26, clean Apple virtual machine
- Ubuntu 26.04 arm64, clean Apple Silicon virtual machine

## Rules

- Keep one stopped base machine after each operating system is installed and before the repo installer runs.
- Save one clean snapshot after the OS setup finishes. For every first-run test, make a disposable UTM clone from the clean base and leave the base stopped and unchanged.
- Copy or clone the repo inside the guest. Do not run from a read-only shared folder.
- On macOS, log in to the desktop before starting the installer so its desktop changes have an active session.
- Save the full terminal output for every run.
- After a first run passes, reboot the same test clone, log back in when needed, and run the same installer a second time without cleaning the machine.
- Delete the disposable clone after both runs and checks pass.
- A test only passes when the commands succeed and the result is checked in the desktop.
- Use `bash scripts/install.sh apps`, `desktop`, or another named part while fixing one part. Use the command with no part for final clean runs.

## Runs

| Run            | macOS choice                                | Ubuntu choice                              | Status                                                                                |
| -------------- | ------------------------------------------- | ------------------------------------------ | ------------------------------------------------------------------------------------- |
| App install A  | Tailscale command-line service, NordVPN yes | Tailscale service, NordVPN yes             | Both passed twice                                                                     |
| App install B  | Tailscale menu bar app, NordVPN no          | Tailscale skipped, NordVPN no              | Both passed; macOS passed twice                                                       |
| App install C  | Tailscale skipped                           | Tailscale service                          | Ubuntu service choice covered by A; macOS not run                                     |
| Desktop A      | Dock hidden, small, bottom                  | Dock hidden, small, bottom                 | Both passed                                                                           |
| Desktop B      | Dock shown, large, left                     | Dock shown, large, left                    | Ubuntu passed; macOS pending                                                          |
| Desktop C      | Dock unchanged, medium, right               | Dock unchanged, medium, right              | Ubuntu passed; macOS pending                                                          |
| Wallpaper A    | Apply machine wallpaper                     | Apply machine wallpaper                    | Both passed                                                                           |
| Wallpaper B    | Keep current wallpaper                      | Keep current wallpaper                     | Ubuntu passed; macOS pending                                                          |
| Theme A        | Apply dark theme and machine color          | Apply dark theme and machine color         | Both passed                                                                           |
| Theme B        | Keep current theme                          | Keep current theme                         | Ubuntu passed; macOS pending                                                          |
| Icons          | Built-in clear icons                        | MacTahoe blue dark icons                   | Both passed                                                                           |
| Development    | Node, Zsh, tmux, VSCodium, and Skills       | Node, Zsh, tmux, VSCodium, and Skills      | Both passed                                                                           |
| Input          | Pointer, touchpad, keyboard, and remapping  | Pointer, touchpad, keyboard, and remapping | Both passed                                                                           |
| Default apps   | Chrome browser                              | Chrome or Brave browser, Ghostty terminal  | Both passed                                                                           |
| Files          | Associations, preferences, and sidebar      | Associations, preferences, and sidebar     | Both passed; macOS 26 skips protected associations and sidebar entries                |
| Remote A       | Enable remote access                        | Enable remote access                       | Ubuntu passed; macOS pending                                                          |
| Remote B       | Skip remote access                          | Skip remote access                         | Both passed                                                                           |
| Power A        | Normal                                      | Normal                                     | Both passed                                                                           |
| Power B        | Server                                      | Server                                     | Ubuntu passed; macOS pending                                                          |
| Power C        | Skip                                        | Skip                                       | Ubuntu passed; macOS pending                                                          |
| Full clean run | All normal choices                          | All normal choices                         | Both passed                                                                           |
| Second run     | Reboot, log in, and run again               | Reboot and run again                       | Both full runs passed twice                                                           |
| CPU support    | Native Mac CPU                              | Ubuntu amd64 and arm64 paths               | AMD64 official package checks and earlier live evidence passed; ARM64 live run passed |

## Results so far

- The optional Git configuration and GitHub browser-login step passed local prompt, setting, login, and repeat-run checks. It has not yet been checked in the clean macOS and Ubuntu VM clones.

- On 2026-07-14, both reusable base VMs stayed stopped while new disposable UTM clones were tested. Each clone started with a fresh repo clone. Ubuntu ARM64 passed the full clean install, reboot, second full install, and both result checks. Native Mac ARM64 passed the same sequence after logging in to the desktop before each run. The Mac test used `8fab8ff`; the Ubuntu test used `64cfbd0`, whose installer files are identical to `8fab8ff` because the later commit only added `TODO.md`, `icon.png`, and their `.gitignore` entries. Both disposable clones were deleted after the checks. Logs are under `.test-logs/vm-retest-2026-07-14/`.

- The Ubuntu 26.04 amd64 ISO matched Canonical's published SHA-256 checksum before the base machine was installed.
- Canonical's Ubuntu 26.04 arm64 desktop image matched its published `c2afd538d66fdd77377d03f1ed2ac76a34f1c116baecc9a8170d68f833121f57` SHA-256 checksum.
- `Clean Ubuntu 26.04 arm64` was created with native CPU virtualization, 6 cores, 6 GB of memory, a 128 GB disk, and the verified arm64 ISO. The old translated amd64 VM and ISO were removed.
- Ubuntu was installed once with user `m4` and computer name `m4-vm`. At the completed-install screen the VM was stopped, the ISO was removed, and the disk passed `qemu-img check` with no errors.
- The stopped pre-first-boot disk was saved as the verified internal snapshot `clean-base`. Its matching EFI state is saved as `efi_vars.clean-base.fd`; both are restored before every first-run test.
- Linux detects `LINUX_ARCH` once at startup. AMD64 keeps Google Chrome and OpenWhispr; arm64 uses Brave and whisper.cpp.
- Official arm64 package indexes contained Brave, VSCodium, Docker, Firefox, Cloudflared, Tailscale, and NordVPN. GitHub releases contained checksum-backed arm64 files for Codex, OpenCode, and whisper.cpp. Canonical's arm64 indexes contained every Ubuntu package named by the installer.
- `Clean macOS 26` is the one reusable Apple virtual machine. It uses Apple's native arm64 virtualization with 6 cores, 8 GB of memory, and no Intel translation.
- macOS 26.5.2 was installed once with user `m4` and computer name `m4-vm`. FileVault is off.
- The stopped `clean-base` snapshot contains the finished OS only. The stopped `test-ready` snapshot adds temporary SSH access, Expect, and Apple's command-line tools. It has no repo checkout or Homebrew install, so every test starts with a fresh clone.
- The Mac snapshots are copy-on-write copies under `Clean macOS 26.utm/Snapshots/`. Restore `test-ready` only while the VM is stopped:

  ```zsh
  VM="$HOME/Library/Containers/com.utmapp.UTM/Data/Documents/Clean macOS 26.utm"
  SNAP="$VM/Snapshots/test-ready"
  cp -c -f "$SNAP/8DEFE143-36C9-4B96-BDCF-5C8E5F91CA1E.img" "$VM/Data/8DEFE143-36C9-4B96-BDCF-5C8E5F91CA1E.img"
  cp -c -f "$SNAP/AuxiliaryStorage" "$VM/Data/AuxiliaryStorage"
  cp -c -f "$SNAP/config.plist" "$VM/config.plist"
  ```

- The strategy shape and Bash syntax checks passed.
- The first app run passed with Tailscale's command-line service and NordVPN selected.
- `brew services list` showed Tailscale started as root from `/Library/LaunchDaemons/homebrew.mxcl.tailscale.plist`.
- VSCodium, Ghostty, Chrome, Firefox, OpenCode, and Codex opened successfully.
- Docker opened, then reported that nested virtualization is unavailable in the UTM macOS guest. Its install succeeded; its engine cannot be tested inside this guest.
- The same app run passed again without restoring the machine. Homebrew reported the apps current, and the running Tailscale service was kept running.
- A second clean Mac app choice run passed twice without restoring the machine.
- Mac development, wallpaper, theme, pointer and input, desktop, file, remote-skip, and normal-power parts passed separately before the full run.
- macOS 26 asks for approval for every file association and protects Finder sidebar files. The installer now reports this and leaves those two sets of values unchanged instead of opening approval windows. The rest of the file preferences passed.
- The Mac full clean run passed with the normal choices, a hidden small bottom Dock, remote access skipped, the command-line Tailscale service, and NordVPN selected. The exact same command passed again without a restore.
- macOS requires the signed-in user to approve a default-browser change. The installer now opens one native prompt, waits for **Use Chrome**, and checks that both HTTP and HTTPS use Chrome before continuing.
- After reboot, the guest was still arm64 and named `m4-vm`. The wallpaper, dark theme, hidden bottom Dock, Node 24, VSCodium extensions, skill links, and root Tailscale service were checked. VSCodium, Ghostty, Chrome, Firefox, Docker, OpenCode, Codex, NordVPN, and UTM were installed.
- Full Mac logs, including both full passes and the final macOS 26 file check, are saved on the host under `.test-logs/macos-arm64-2026-07-13/`. The folder is ignored because test output is not source code.
- The Ubuntu ARM64 app run passed, then the same app run passed again without a restore. Cloudflared, Fastfetch, GitHub CLI, Neovim, tmux, Ghostty, VSCodium, Codex, Docker, Brave, Firefox, whisper.cpp, Zsh, wl-copy, Tailscale, and NordVPN were checked from the guest.
- VSCodium, Brave, Firefox, and Ghostty opened in the Ubuntu desktop. OpenCode installed and its server and window code stayed running, but its Electron window did not become visible under UTM's Wayland display. The guest had free memory, no out-of-memory report, and no app crash. This remains a UTM display limit rather than an ARM64 package failure.
- The tracked wallpaper source is `white.png`. Ubuntu creates a 3840x2160 copy because UTM's virtual display rejected the 6016x3388 texture. The colored wallpaper appeared correctly in the guest. Both apply and skip choices passed.
- All three Ubuntu Dock choice sets passed. Development passed after removing the bad tmux entry that made the plugin manager try to install itself. Input and file settings passed.
- Ubuntu SSH stayed enabled and active. GNOME Remote Desktop now creates a local TLS certificate and starts the matching headless service. Both enable and skip choices passed.
- Normal, server, and skip power choices passed. The Linux power profile change uses `sudo`, and skip choices return success instead of stopping the installer.
- The reusable Ubuntu `test-ready` snapshot contains only the clean OS, guest agent, and Expect. Test prep adds Git and SSH for automation, then makes a fresh clone. The full clean run and its second run started from that snapshot.
- The Ubuntu full clean run passed with all normal choices. The exact same full command passed again without a restore.
- After reboot, the guest was still arm64 and named `m4-vm`. Docker, Tailscale, SSH, and GNOME Remote Desktop were enabled and active. The machine name, wallpaper, dark theme, bottom Dock, and eight skill links in each supported agent folder were also checked.
- Full logs from these runs, including both full passes and the post-reboot check, are saved on the host under `.test-logs/ubuntu-arm64-2026-07-13/`. The folder is ignored because test output is not source code.
- After the macOS fixes in `9f16184`, the current scripts were tested again from the Ubuntu `test-ready` snapshot. The full clean ARM64 run passed, the exact second run passed, and the reboot check confirmed the machine name, wallpaper, dark theme, bottom Dock, apps, services, Node 24, VSCodium extensions, and skill links. These logs are under `.test-logs/ubuntu-arm64-after-macos-2026-07-13/`.
- After the Linux check in `b2b195f`, the current scripts were tested again from the Mac `test-ready` snapshot after logging in to the desktop. The full clean ARM64 run and the exact second run passed. The reboot check confirmed the machine name, FileVault off, wallpaper, dark theme, hidden small bottom Dock, all selected apps, Node 24, VSCodium extensions, eight skill links in each supported agent folder, and the Tailscale service. The VM was then stopped and restored to `test-ready`. These logs are under `.test-logs/macos-arm64-2026-07-13/`.
- The cleanup in `4cdc2b4` and the macOS browser fix in `0caf7ad` were tested again from both clean snapshots. Ubuntu ARM64 and native Mac ARM64 each passed a fresh-clone full install, the exact second run, and a reboot check. The Mac check also confirmed Chrome owns HTTP and HTTPS. Both VMs were stopped and restored afterward. The Mac `test-ready` snapshot was then rebuilt with Apple's command-line tools and no repo checkout, boot-tested, and restored. Logs are under `.test-logs/cleanup-2026-07-13/`.

## Desktop checks

- The required apps open: VSCodium, Ghostty, Chrome or Brave, Firefox, Docker, OpenCode, and the platform matches for the other Mac apps.
- Web links open in Chrome on macOS and Ubuntu AMD64 or Brave on Ubuntu ARM64. Ubuntu terminal requests open in Ghostty.
- JetBrains Mono is available.
- The Dock has the requested size, place, visibility, and app order.
- The machine name is in the menu bar. On Ubuntu it is the only item centered in the top bar and the clock is on the right.
- The machine-color wallpaper, dark theme, pointer, touchpad, keyboard, workspaces, desktop icons, and window settings match the chosen run.
- VSCodium owns the code and config file types.
- Finder or Files has the requested view, trash, and sidebar settings.
- SSH and screen sharing work from the other guest when enabled.
- Update and power settings match the chosen run.
- Skills appear in each supported agent folder.

## Git checks

- Skip Git setup and confirm the rest of the development part continues without changing Git or GitHub settings.
- Confirm Git LFS is absent after skipping, or installed and initialized after accepting, with `git lfs version` and the global `filter.lfs` settings.
- Accept the three defaults, then repeat with another name, email, and default branch. Confirm later runs show the saved values.
- Confirm the fixed push, fetch, pull, merge, and diff settings match the values documented in `setup/development/git.sh`.
- Skip GitHub sign-in and confirm no credential helper is added.
- Sign in through the browser and confirm `gh auth status --hostname github.com` passes, `gh` did not fall back to plain-text token storage, and an HTTPS private repository can fetch without another login.
- Run the development part again and confirm it reuses the saved GitHub login.
- Start a new shell and confirm `GITHUB_TOKEN` is not set by `.zshrc`.
