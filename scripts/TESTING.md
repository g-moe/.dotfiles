# Clean install checks

All installer runs happen inside UTM. Do not run the installer or its tests on the main Mac.

## Machines

- macOS 26, clean Apple virtual machine
- Ubuntu 26.04 amd64, clean virtual machine

## Rules

- Keep one untouched base machine after each operating system is installed and before the repo installer runs.
- Clone that base machine before every first-run test.
- Copy or clone the repo inside the guest. Do not run from a read-only shared folder.
- Save the full terminal output for every run.
- After a first run passes, run the same installer a second time without cleaning the machine.
- A test only passes when the commands succeed and the result is checked in the desktop.
- Use `bash scripts/install.sh apps`, `desktop`, or another named part while fixing one part. Use the command with no part for final clean runs.

## Runs

| Run | macOS choice | Ubuntu choice | Status |
| --- | --- | --- | --- |
| App install A | Tailscale command-line service, NordVPN yes | Tailscale service, NordVPN yes | macOS passed twice; Ubuntu not run |
| App install B | Tailscale menu bar app, NordVPN no | Tailscale skipped, NordVPN no | Not run |
| App install C | Tailscale skipped | Tailscale service | Not run |
| Desktop A | Dock hidden, small, bottom | Dock hidden, small, bottom | Not run |
| Desktop B | Dock shown, large, left | Dock shown, large, left | Not run |
| Desktop C | Dock unchanged, medium, right | Dock unchanged, medium, right | Not run |
| Wallpaper A | Apply machine wallpaper | Apply machine wallpaper | Not run |
| Wallpaper B | Keep current wallpaper | Keep current wallpaper | Not run |
| Remote A | Enable remote access | Enable remote access | Not run |
| Remote B | Skip remote access | Skip remote access | Not run |
| Power A | Normal | Normal | Not run |
| Power B | Server | Server | Not run |
| Power C | Skip | Skip | Not run |
| Full clean run | All normal choices | All normal choices | Not run |
| Second run | Run again without a restore | Run again without a restore | macOS apps passed; Ubuntu not run |

## Results so far

- The Ubuntu 26.04 amd64 ISO matched Canonical's published SHA-256 checksum before the base machine was installed.
- `macOS Apps CLI` was cloned from the untouched `Clean macOS 26` base before the run.
- The strategy shape and Bash syntax check passed inside that clean Mac guest.
- The first app run passed with Tailscale's command-line service and NordVPN selected.
- `brew services list` showed Tailscale started as root from `/Library/LaunchDaemons/homebrew.mxcl.tailscale.plist`.
- VSCodium, Ghostty, Chrome, Firefox, OpenCode, and Codex opened successfully.
- Docker opened, then reported that nested virtualization is unavailable in the UTM macOS guest. Its install succeeded; its engine cannot be tested inside this guest.
- The same app run passed again without restoring the machine. Homebrew reported the apps current, and the running Tailscale service was kept running.
- The first Ubuntu app run stopped at Firefox. A clean Ubuntu 26.04 machine carries a Snap placeholder package with a higher version number than Mozilla's APT package, so unattended APT refused the replacement. The Firefox strategy now purges Ubuntu's Snap copy without saving an empty fresh-machine snapshot, removes the placeholder, and installs Mozilla's APT package. That fix passed in the next fresh clone.
- The next clean Ubuntu app run passed the Firefox fix and then stopped at OpenWhispr. Its release-file match had one extra backslash, so it could not see the published Linux package. The match and installed-command check are fixed and need a fresh-clone run.
- A third Ubuntu clone could not start because the host disk was full, so the installer never ran there. The three failed Ubuntu clones were removed. Testing now keeps one disposable Ubuntu clone at a time; both untouched base machines remain stopped and unchanged.

## Desktop checks

- The required apps open: VSCodium, Ghostty, Chrome, Firefox, Docker, OpenCode, and the platform matches for the other Mac apps.
- JetBrains Mono is available.
- The Dock has the requested size, place, visibility, and app order.
- The machine name is in the menu bar. On Ubuntu it is the only item centered in the top bar and the clock is on the right.
- The machine-color wallpaper, dark theme, pointer, touchpad, keyboard, workspaces, desktop icons, and window settings match the chosen run.
- VSCodium owns the code and config file types.
- Finder or Files has the requested view, trash, and sidebar settings.
- SSH and screen sharing work from the other guest when enabled.
- Update and power settings match the chosen run.
- Skills appear in each supported agent folder.
