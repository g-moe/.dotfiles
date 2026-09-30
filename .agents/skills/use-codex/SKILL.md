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

Invoke Codex through the CLI from the target project directory. Default to `gpt-6.1-sol` with `high` reasoning effort unless the request specifies overrides. Inherit other configured settings:

```bash
CODEX_TASK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/use-codex.XXXXXX")"
# Write the task to "$CODEX_TASK_DIR/prompt.md" before running.
codex exec -m gpt-6.1-sol -c 'model_reasoning_effort="high"' \
  -s read-only -o "$CODEX_TASK_DIR/report.md" - \
  < "$CODEX_TASK_DIR/prompt.md" \
  > "$CODEX_TASK_DIR/stdout.log" 2> "$CODEX_TASK_DIR/stderr.log"
```

## Choose Access and Tools

- Use read-only for reviews and opinions. For tasks needing writes, choose the access required by the authorized task explicitly.

- For computer use, require actual interaction and evidence. If the needed tools are unavailable, report that limitation; do not substitute imagined results.

## Wait for Completion

- Allow enough time for completion; use a background job and check its status if the shell tool's timeout is too short. Do not treat a partial report as success.

## Check the Result

- Check the exit status and read the report. On failure, inspect the logs and report the error. If `codex` is unavailable, report that instead of silently doing the task yourself.

- Verify consequential findings against the code or artifacts before acting on them. Distinguish verified results from claims you have not checked.
