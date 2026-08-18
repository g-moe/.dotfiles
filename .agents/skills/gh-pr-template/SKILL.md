---
name: gh-pr-template
description: Manual only. Fill the repo pull request template for the PR on the current branch. Use only when the user explicitly invokes `$gh-pr-template`.
---

# Workflow

1. Find the open PR for the current working branch with the `gh` CLI. If none exists, stop and tell the user exactly: `Pull-request Not found for current working branch.`
2. Read the branch diff and commits. Ground the write-up in the diff; use commit messages only where they help clear out confusion or uncertainty.
3. Fill `.github/PULL_REQUEST_TEMPLATE.md` for that PR. Complete every section that applies; drop or leave unchecked what does not.
4. Update the existing PR body in place. Do not create a PR.

# Best Practices

- Link directly to commits, files, or external resources only when the link helps the reader.
