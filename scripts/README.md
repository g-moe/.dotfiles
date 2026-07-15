# Machine installer

**One entry point:** `scripts/install.sh`. Every install path goes through it — full run, phase slices, and single strategies (`--git`, `--skills`, `--theme`). Do not run `scripts/setup/**` or `custom-themes/create/controller.ts` yourself for install.

```bash
bash scripts/install.sh                 # full machine
bash scripts/install.sh --apps          # one phase
bash scripts/install.sh --git           # Git only
bash scripts/install.sh --skills        # Skills only
bash scripts/install.sh --theme         # custom-themes generate + install
npm run install:machine                 # → install.sh
npm run install:git                     # → install.sh --git
npm run install:skills                  # → install.sh --skills
npm run install:theme                   # → install.sh --theme
```

Normal user only (not root). `sudo` is used where the OS needs it.

- Agents editing this tree: [AGENTS.md](AGENTS.md)
- VM tests: [TESTING.md](TESTING.md)

---

`install.sh` detects the OS, checks the user, then either runs a single strategy or asks for a **machine name and color** (writes gitignored `machine.json`) and walks phases.

`--git`, `--skills`, and `--theme` skip the identity prompt. Phase flags (`--apps`, …) still ask for machine name/color first. No argument = all phases.

Phase order: `apps` → `development` → `appearance` → `input` → `desktop` → `files` → `access` → `system`.

| Phase         | Covers                                                         |
| ------------- | -------------------------------------------------------------- |
| `apps`        | Apps (Homebrew / APT / vendor)                                 |
| `development` | Git, Node, Zsh, tmux, VSCodium, Skills                         |
| `appearance`  | Wallpaper, screen saver, theme, icons                          |
| `input`       | Pointer, touchpad, keyboard, remapping                         |
| `desktop`     | Workspaces, items/widgets, windows, Dock, name in bar, top bar |
| `files`       | Defaults, associations, Finder/Files                           |
| `access`      | Handoff, assistants, headless notes, SSH, VNC                  |
| `system`      | Updates, power, UI refresh                                     |

### Where things live

```
install.sh          **only** machine-install entry point
setup/<phase>/…     strategies (launched by install.sh with OS as $1)
setup/identity.sh   before phases (skipped for --git / --skills / --theme)
setup/skills.sh     from development (also --skills)
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

| Helper       | Use                           |
| ------------ | ----------------------------- |
| `ask_choice` | Numbered menu → 0-based index |
| `ask_binary` | Yes / no                      |

**Skip / Enable / Disable** is a real triad when those are the labels: `0` skip, `1` enable, `2` disable (SSH, VNC). Everything else keeps domain labels — Dock hide/show, sizes, colors, power Skip/Normal/Server, Tailscale install modes, etc.

### npm scripts

```bash
npm run install:machine  # → install.sh (full)
npm run install:git      # → install.sh --git
npm run install:skills   # → install.sh --skills
npm run install:theme    # → install.sh --theme (custom-themes packs; not OS appearance)
npm run install:test     # shape + lib checks (no VM)
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
