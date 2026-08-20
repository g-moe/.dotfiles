## Summary

<!-- 1–3 bullets. Lead with why, not a file list. -->

-

## Touch-Points

<!-- Keep only what this PR touches. -->

- [ ] Skills / agents
- [ ] Shell / terminal (zsh, tmux, ghostty, nvim, …)
- [ ] Installer / machine setup
- [ ] Packages (`mac`, `raycast`, `theming`, `vscode-ext`, `lib`)
- [ ] App / editor config
- [ ] Docs / repo meta (`.gitignore`, `AGENTS.md`, GitHub)

## Test plan

<!-- Check only what applies. Name the exact commands you ran. -->

- [ ]
- [ ] `npm run install:test` (installer shape / lib changes)
- [ ] `npm run verify:machine` (symlink / install surface)
- [ ] `npm run install:agents` (agent path / link changes)
- [ ] Re-sourced shell or restarted the affected app

## Repo checklist

- [ ] New tracked paths are whitelisted in the root `.gitignore`
- [ ] Touched `.md` files are current (prefer patch-only docs)
- [ ] Package boundaries hold (nothing depends on `packages/installer`)
