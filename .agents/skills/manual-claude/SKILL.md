---
name: manual-claude
description: Manual only. Use only when the user explicitly invokes $manual-claude. Never invoke it from a plain mention of Claude or an implicit request.
---

# Manual Claude

After the user invokes `$manual-claude` once, Claude use is authorized for the rest of the current chat. Stop when the chat ends or the user revokes authorization. Never carry authorization to another chat.

Use these defaults unless the user changes them:

```bash
MODEL=fable
EFFORT=high
```

Call Claude Code in non-interactive mode:

```bash
claude -p "$PROMPT" --output-format json \
  --model "$MODEL" --effort "$EFFORT" \
  --dangerously-skip-permissions
```

Use the returned session ID with `--resume` for follow-up prompts. Read Claude's response and inspect its work yourself.

For code changes, give Claude a separate Git worktree on a `garrett/` branch. Do not install or authenticate Claude Code unless the user asks.
