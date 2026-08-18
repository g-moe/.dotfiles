---
name: gh-pr-comments
description: Manual only. Handle GitHub PR review comments for the PR on the current branch. Use only when the user explicitly invokes `$gh-pr-comments`.
---

# Workflow

1. Find the open PR for the current working branch with the `gh` CLI. If none exists, stop and tell the user exactly: `Pull-request Not found for current working branch.`
2. Load review comments and issue comments on that PR.
3. Treat login `g-moe` as the user. Skip any `g-moe` comment that uses the agent reply shape below — those are agent-authored and must not be handled again.
4. Handle the remaining comments that still need a response. When you reply as the user, use the agent reply shape.
5. If a comment requests a code fix: make the fix, commit it in its **own** commit (one comment’s fix per commit), then reply in the `Links` section with a link to that commit like [Commit](https://example.com/commit). Do not reply before the commit exists.

# Agent reply shape

Every agent-authored comment or reply must use this exact field layout (each field on its own line). Omit `Links` when none apply.

```text
Model: <model name>
Response: <reply body>
Links: <commit, file, or other URL — only when it helps>
```

`Response` may include whatever is needed to get the point across or finish the request — sentences, lists, code blocks, patches, commands, images and so on.

Infer the right action from the comment: answer questions; turn statements and requested changes into fixes (code and/or reply). Do not ask the user which of those it is. For fix requests, the commit comes first; the reply’s `Links` must point at that commit.

# Rules

- Do not reply to comments that already match the agent reply shape.
- Do not reply to ANY comments that were not initiated by `g-moe`.
- Link only when the link helps; prefer commit and file URLs.
- Never bundle unrelated comment fixes into one commit.
