---
name: use-codex
description: Transform the user's request into a prompt and invoke Codex through the CLI, preserving requested skills and constraints.
---

# Use Codex

## Prepare the Prompt

Take the user's request and transform it into a self-contained prompt for Codex. Preserve their intent, scope, constraints, requested model/settings, and explicit skill invocations such as `$skill-name`. Include the working directory and relevant conversation context; Codex does not inherit this conversation.

## Preserve Skill Invocations

Identify requested skills as the user's explicit invocations and instruct Codex to load and follow them. Preserve skill names literally when writing the prompt file; do not let the shell expand `$skill-name`. If a requested skill is unavailable, report it rather than silently substituting another workflow. Tell Codex to complete the task without invoking use-codex again.

## Invoke the CLI

Invoke Codex through the CLI from the target project directory. Default to `gpt-6.1-sol` with `high` reasoning effort unless the request specifies overrides. Tools, MCP servers, and their approvals come from `~/.codex/config.toml`; do not override them here.

```bash
CODEX_TASK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/use-codex.XXXXXX")"
# Write the task to "$CODEX_TASK_DIR/prompt.md" before running.
codex exec --skip-git-repo-check -m gpt-6.1-sol -c 'model_reasoning_effort="high"' \
  -s danger-full-access -o "$CODEX_TASK_DIR/report.md" - \
  < "$CODEX_TASK_DIR/prompt.md" \
  > "$CODEX_TASK_DIR/stdout.log" 2> "$CODEX_TASK_DIR/stderr.log"
```

`stderr.log` holds Codex's full transcript, not only errors: the session ID, every tool call, and the final message.

## Choose Access and Tools

- Codex runs with full access. Scope comes from the prompt: state what Codex may and may not change (for example, "only add reproducer `*.test.ts` files; do not edit source"), and carry over every project rule that applies, such as `AGENTS.md` prohibitions.

- For browser tasks, tell Codex to use the chrome-devtools MCP tools, name each tool it called, and save screenshots to `$CODEX_TASK_DIR` as evidence. The browser is headless and isolated, so it has no signed-in sessions.

## Wait for Completion

- Run Codex as a background job and tell the user it is running. Do not treat a partial report as success.

## Check the Result

- Check the exit status and read the report. On failure, inspect `stderr.log` and report the error. If `codex` is unavailable, report that instead of silently doing the task yourself.

- For browser tasks, confirm the `mcp: chrome-devtools/...` calls in `stderr.log` and open the screenshots before trusting Codex's claims.

- Verify consequential findings against the code or artifacts before acting on them. Distinguish verified results from claims you have not checked.

- End with the session ID from the `session id:` line in `stderr.log` and the command to reopen it: `codex resume --include-non-interactive <id>`.
