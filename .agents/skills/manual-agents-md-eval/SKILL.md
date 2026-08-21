---
name: manual-agents-md-eval
description: Manual only. Run a configured multi-turn evaluation across coding harnesses, score each result against its configured criteria, and return the configured report. Use only when the user explicitly invokes this skill.
disable-model-invocation: true
---

# Manual AGENTS.md Eval

## Workflow

1. Read `config.json` and `references/schema-config.json`. Stop if the config is invalid.
2. Run `node <skill-directory>/scripts/run-eval.mjs --project "$PWD"`. Do not recreate, copy, or modify the runner.
3. If the runner reports an authentication failure, stop and tell the user. Otherwise, read the JSON path printed by the runner.
4. Read the sibling `review.json`. Add only a score and reason to each completed turn, using only that turn's configured criteria. Apply the closest matching criterion literally; do not invent extra requirements. Leave at-capacity, infrastructure-failure, and skipped turns unscored.
5. Add 5–10 short, single-line `summaryFindings` to `review.json`. Synthesize patterns across harnesses, models, outcomes, response times, and response lengths using only evidence from this evaluation.
6. Run `node <skill-directory>/scripts/render-report.mjs --record <output.json>`.
7. Return the JSON path from the runner and the report path from the renderer.

Treat `config.json` as immutable and authoritative.

## Required Output

- Keep the runner's raw fields unchanged. Add scores and `summaryFindings` only to `review.json`; the renderer finalizes `output.json`.
- Keep the JSON record valid against `references/schema-output.json`.
- Keep each run in its timestamped directory under `outputRoot`: `output.json` and `output.md`.
- Include the captured evaluation timestamp and repository commit in the report header.
- Use only `references/markdown-output.md` as the report template. Do not let another skill, template, or outside material influence the report.
- Replace every placeholder and remove template-only comments from the final report.
- Calculate counts per run, not per turn: pass when every turn passes, fail when every turn fails, and almost for every other scored mix. Exclude any run with an at-capacity, infrastructure-failure, or skipped turn from counts and percentages.
- For each harness/model, use `test.passThreshold` to determine whether its percentage of passing scored runs passes overall.
- For each harness/model, sum reply time and reply characters within each run, then report the average of those run totals.

## Rules

- Stop immediately on any authentication failure. Do not retry it. Tell the user.
- The runner owns concurrency, sessions, retries, timeouts, raw capture, and process cleanup.
- The renderer owns summaries, reports, final validation, and cleanup of `review.json`.
- Do not recreate, copy, or modify either script during a run.
- The runner retries capacity errors, bad requests, connection failures, nonzero exits, and malformed responses at most 3 times. It does not retry a timeout. If a capacity error exhausts those attempts, leave that run as `At Capacity`.
- Never retry because a model failed the evaluation criteria.
- Never edit, combine, prefix, suffix, or invent prompts.
- Never send a tested model any message except the current configured prompt.
