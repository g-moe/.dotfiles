# Dummy PR sample

Fixture for testing `$gh-pr-template` and `$gh-pr-comments`. Replace or expand as those skills gain content. Mirrors `.github/PULL_REQUEST_TEMPLATE.md`.

## Summary

- Add a no-op placeholder file so `$gh-pr-template` / `$gh-pr-comments` have a filled PR body and fake review threads to practice against without touching real product code.
- Pure fixture: no installers, packages, or runtime config change when this sample alone is present.

## Touch-Points

- [x] Skills / agents
- [ ] Shell / terminal (zsh, tmux, ghostty, nvim, …)
- [ ] Installer / machine setup
- [ ] Packages (`mac`, `raycast`, `theming`, `vscode-ext`, `lib`)
- [ ] App / editor config
- [x] Docs / repo meta (`.gitignore`, `AGENTS.md`, GitHub)

## Test plan

- [x] Open this file and confirm both skills can reference it
- [ ] Run `$gh-pr-template` against this sample and inspect the draft body
- [ ] Run `$gh-pr-comments` against the fake comments below
- [ ] `npm run install:test` (installer shape / lib changes)
- [ ] `npm run verify:machine` (symlink / install surface)
- [ ] `npm run install:skills` (skill path / link changes)
- [ ] Re-sourced shell or restarted the affected app

## Repo checklist

- [x] New tracked paths are whitelisted in the root `.gitignore`
- [x] Touched `.md` files are current (prefer patch-only docs)
- [x] Package boundaries hold (nothing depends on `packages/installer`)

## Fake review comments

1. **reviewer (@alice):** Nit: rename `placeholder` to something domain-specific before merge.
2. **bugbot:** Possible unused export in the touched module — confirm or remove.
3. **reviewer (@bob):** Can we add a one-line note in the nearest README that this path is intentional?
4. **g-moe (human):** Keep the sample path under `.agents/skills/samples/`.
5. **g-moe (agent — skip):**
   ```text
   Model: example-model
   Response: Renamed the sample path and left a short README note.
   Links: https://github.com/example/commit/abc123
   ```

