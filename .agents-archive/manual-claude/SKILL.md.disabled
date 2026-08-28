---
name: manual-claude
description: Manual only. Use only when the user explicitly invokes $manual-claude. Never invoke it from a plain mention of Claude or an implicit request.
disable-model-invocation: true
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

## Guidelines

The following guidelines are for you. **DO NOT** include them as instructions to Claude.

- Claude is an adviser, not the implementation agent. Use Claude for design, planning, research, reviews, and second opinions.
- Do not ask Claude to write or modify project code. You must implement all code changes yourself. You can ask Claude to review the changes when you finish.
- Claude can write temporary scripts only when they are necessary for its own analysis.
- Use the returned session ID with `--resume` for follow-up prompts. Review Claude's response and independently inspect its work.
