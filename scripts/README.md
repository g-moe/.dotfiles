# Machine installer

One command sets up a clean **macOS** or **Ubuntu 26.04** (amd64 / arm64) machine:

```bash
bash scripts/install.sh
# npm run install:machine
```

Normal user only (not root). `sudo` is used where the OS needs it.

- Agents editing this tree: [AGENTS.md](AGENTS.md)
- VM tests: [TESTING.md](TESTING.md)

---

You start `install.sh`. It detects the OS, checks the user, asks for a **machine name and color**, writes gitignored `machine.json` at the repo root, then walks phases. No argument = all phases. A phase name = just that slice:

```bash
bash scripts/install.sh apps
bash scripts/install.sh desktop
```

Order: `apps` → `development` → `appearance` → `input` → `desktop` → `files` → `access` → `system`.

| Phase | Covers |
| --- | --- |
| `apps` | Apps (Homebrew / APT / vendor) |
| `development` | Git, Node, Zsh, tmux, VSCodium, Skills |
| `appearance` | Wallpaper, screen saver, theme, icons |
| `input` | Pointer, touchpad, keyboard, remapping |
| `desktop` | Workspaces, items/widgets, windows, Dock, name in bar, top bar |
| `files` | Defaults, associations, Finder/Files |
| `access` | Handoff, assistants, headless notes, SSH, VNC |
| `system` | Updates, power, UI refresh |

### Where things live

```
install.sh          entry point
setup/<phase>/…     one feature per file (Mac + Linux together)
setup/identity.sh   always, before the phase
setup/skills.sh     from development
lib/lib.sh          only library entry (barrel)
tests/              shape + lib checks
shared/shared-*.sh  cross-OS tools outside install
mac/mac-*.sh        Mac-only tools outside install
```

### A strategy file

`install.sh` runs each setup file in a **new** Bash process with the OS as `$1`, so every file can define plain `mac()` / `linux()`:

```bash
install_vscodium() {
  case "$1" in
    mac) mac ;;
    linux) linux ;;
    *) die "Unsupported OS: $1" ;;
  esac
}

mac() { brew_cask vscodium; }
linux() { apt_install codium; }

install_vscodium "$1"
```

Source `lib/lib.sh` at the top. Shape is enforced by `npm run install:test` (registration once, both platform functions, `return 0` on skips, no per-file CPU detect, no migration wording).

### Prompts

| Helper | Use |
| --- | --- |
| `ask_choice` | Numbered menu → 0-based index |
| `ask_binary` | Yes / no |

**Skip / Enable / Disable** is a real triad when those are the labels: `0` skip, `1` enable, `2` disable (SSH, VNC). Everything else keeps domain labels — Dock hide/show, sizes, colors, power Skip/Normal/Server, Tailscale install modes, etc.

### Extra entry points

```bash
npm run install:git      # Git + LFS + optional GitHub login
npm run install:skills   # skill links only
npm run install:test     # shape + lib (no VM)
```

### Platform quirks

- **Packages:** Homebrew on Mac; APT on Ubuntu unless the vendor has no APT package.
- **Clean only:** no “move my old dotfiles” path.
- **`$LINUX_ARCH`:** set once. amd64 → Chrome + OpenWhispr; arm64 → Brave + whisper.cpp.
- **Firefox (Ubuntu):** Snap removed; Mozilla APT installed.
- **CleanShot X:** Mac only.
- **Defaults:** Chrome (Mac + Ubuntu amd64) or Brave (Ubuntu arm64); Ghostty as Ubuntu terminal. Mac shows a system browser prompt — pick **Use Chrome**.
- **Wallpaper:** from tracked `white.png` + machine color; Ubuntu forced to 3840×2160 for UTM.
- **Icons:** Ubuntu gets pinned MacTahoe blue-dark; Mac keeps stock.
- **Git:** optional; defaults `garrett` / noreply email / `main`; GitHub login is a separate browser step; no token in the shell env.
- **VNC:** Screen Sharing on Mac, GNOME Remote Desktop on Ubuntu (same strategy).
