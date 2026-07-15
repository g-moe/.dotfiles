# Clean install checks

Full installer proof runs in **UTM only** — never on the main Mac.

No-VM sanity anytime:

```bash
npm run install:test
```

---

## Hard rules

1. Run install **only** via `bash scripts/install.sh` (or `npm run install:machine` / `install:git` / `install:skills` / `install:theme`). Never call `scripts/setup/…` or `custom-themes/create/controller.ts` directly for install.
2. One stopped **base** per OS (OS installed, this repo’s installer never run on it).
3. Every first-run test = **disposable clone**. Base stays stopped and untouched.
4. Repo lives **inside** the guest (not a read-only share).
5. macOS: log into the desktop before you start.
6. Save the full terminal log (host `.test-logs/`, gitignored).
7. Pass once → reboot same clone → run the **same** command again → check again.
8. Pass = commands OK **and** desktop matches the checklist.
9. Then delete the clone (or restore the snapshot for the next run).
10. Iterate with `bash scripts/install.sh --<phase>`; finals use no arg.

## Guests

| | macOS 26 | Ubuntu 26.04 arm64 |
| --- | --- | --- |
| Virt | Native Apple arm64 | Native Apple Silicon |
| User / name | `m4` / `m4-vm` | `m4` / `m4-vm` |
| Notes | FileVault off | amd64 paths checked via indexes; live full proof is arm64 |

**macOS snapshots:** `clean-base` = OS only. `test-ready` = OS + SSH/Expect/CLT, **no** repo, **no** Homebrew. Restore only while stopped:

```zsh
VM="$HOME/Library/Containers/com.utmapp.UTM/Data/Documents/Clean macOS 26.utm"
SNAP="$VM/Snapshots/test-ready"
cp -c -f "$SNAP/8DEFE143-36C9-4B96-BDCF-5C8E5F91CA1E.img" "$VM/Data/8DEFE143-36C9-4B96-BDCF-5C8E5F91CA1E.img"
cp -c -f "$SNAP/AuxiliaryStorage" "$VM/Data/AuxiliaryStorage"
cp -c -f "$SNAP/config.plist" "$VM/config.plist"
```

**Ubuntu snapshots:** `clean-base` = verified pre-first-boot disk (+ EFI). `test-ready` = OS + guest agent + Expect. Prep adds Git/SSH, then a fresh clone.

## Recipe

1. Clone from base (or restore `test-ready`). Leave base alone.
2. Boot. Mac → desktop login.
3. Clone repo in guest → run phase or full install.
4. Desktop checklist.
5. Reboot → same install → checklist again.
6. Copy logs to host → stop → delete clone / restore snapshot.

## Scoreboard

| Run | macOS | Ubuntu | Status |
| --- | --- | --- | --- |
| App A | Tailscale CLI + NordVPN yes | Tailscale service + NordVPN yes | Both ×2 |
| App B | Tailscale menu bar + NordVPN no | Both skip | Both; Mac ×2 |
| App C | Tailscale skip | Tailscale service | Ubuntu via A; Mac not run |
| Desktop A | Dock hidden, small, bottom | Same | Both |
| Desktop B | Dock shown, large, left | Same | Ubuntu; Mac pending |
| Desktop C | Dock unchanged | Same | Pending (skip fix) |
| Wallpaper A/B | Apply / keep | Same | A both; B Ubuntu, Mac pending |
| Theme A/B | Apply / keep | Same | A both; B Ubuntu, Mac pending |
| Icons | Built-in | MacTahoe blue dark | Both |
| Development | Node, Zsh, tmux, VSCodium, Skills | Same | Both |
| Input | Pointer…remapping | Same | Both |
| Default apps | Chrome | Chrome/Brave + Ghostty | Both |
| Files | Assoc / prefs / sidebar | Same | Both; Mac 26 skips protected bits |
| SSH A/B/C | Enable / Skip / Disable | Same | Pending (new triad prompts) |
| VNC A/B/C | Screen Sharing triad | GNOME Remote Desktop triad | Pending (new triad prompts) |
| Power A/B/C | Normal / Server / Skip | Same | A both; B/C Ubuntu, Mac pending |
| Full clean | Normal choices | Normal choices | Both |
| Second run | Reboot + again | Reboot + again | Both ×2 |
| CPU | Native Mac | amd64+arm64 paths | Indexes + arm64 live |

## Pass checklists

**Desktop** — apps open; browser/terminal defaults; JetBrains Mono; Dock; name in bar; wallpaper/theme/input/desktop; VSCodium/`code`; Finder/Files; SSH/VNC when enabled; updates/power; Skills linked.

**Git** — `npm run install:git` / `install.sh --git` only; skip leaves Git alone; accept → LFS + filters; name/email/branch stick; settings match `git.sh`; GitHub skip vs browser login; no `GITHUB_TOKEN` in a new shell.

## Known limits

- Mac UTM: Docker installs; engine needs nested virt (unavailable).
- Ubuntu UTM: OpenCode may run headless with no visible window (display, not arm64 package).
- macOS: protected associations / Finder sidebar — installer skips instead of fighting prompts.

## Recent full proofs

Bases frozen; clones disposable.

| When | Where | At | Logs |
| --- | --- | --- | --- |
| 2026-07-14 | Mac + Ubuntu arm64 | `8fab8ff` / `64cfbd0` (installer same) | `.test-logs/vm-retest-2026-07-14/` |
| 2026-07-13 | Both | `4cdc2b4` / `0caf7ad` | `.test-logs/cleanup-2026-07-13/` |
| 2026-07-13 | Ubuntu | after `9f16184` | `.test-logs/ubuntu-arm64-after-macos-2026-07-13/` |
| 2026-07-13 | Mac | after `b2b195f` | `.test-logs/macos-arm64-2026-07-13/` |

Still owed: Git on clean VM clones; SSH/VNC A/B/C after the Skip/Enable/Disable split.
