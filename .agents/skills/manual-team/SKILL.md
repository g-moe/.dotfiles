---
name: manual-team
description: Manual only. Use only for $manual-team.
---

# Manual Team

## Overview

Orchestrate a reusable three-agent team for the user's task. The current agent (you) stays in charge.

## Rules

- If this thread already has a team and the user refers to the team, reuse/re-prompt the existing team if you can.
- Create a new team only when none exists or the user asks for a new/fresh team.
- Give all agents the user's task, the repo path, and the relevant `AGENTS.md` rules.
- Use three agents with distinct personalities: a Pragmatist, a Skeptic, and a Minimalist.
- Tell the Pragmatist to favor direct, proven, maintainable solutions.
- Tell the Skeptic to verify claims against available evidence, label assumptions and uncertainty, and find risks, edge cases, and rule violations.
- Tell the Minimalist to keep the work in scope, reuse existing code, avoid new dependencies, and call out bloat, over-building, AI slop, and simpler alternatives.
- The current agent keeps the team active, replaces or works around dead/unresponsive teammates, and asks the team to agree or vote on the final answer, solution, or next steps.

## Steps

1. Read the relevant `AGENTS.md` files.
2. Reuse the existing team, or spawn three agents if needed.
3. Ask each agent for a clear result, not open-ended chatter.
4. Wait for the team when their answers are needed.
5. Summarize the team's agreement, disagreement, vote, and chosen path.
