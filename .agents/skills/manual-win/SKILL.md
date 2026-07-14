---
name: manual-win
description: Manual only. Use only for $manual-win to find, prove, implement, and unanimously review one small codebase win or improvement.
---

# Manual Win

## Goal

1. Analyze the codebase.
2. Find one small win or improvement then implement.
3. Prove the shortcoming with a standalone script, test, or other clear check. Show that the proof fails before the fix and passes after it.
4. Present the small fix, proof, and results to the `$manual-subagent-team` team.
5. If the team votes 3-0 to approve, present to the user why it is a win and what it is actually solving or improving.
6. If the team cannot approve it 3-0 after back-and-forth to agree, move on to a new small win or improvement.

## Rules

- Keep the improvement small and focused. Do not turn it into a larger cleanup.
- Make the proof stand on its own so another person can run it and see the old shortcoming and the fixed result.
- Use `$manual-subagent-team` for the review. The three subagents cast the votes; the current agent stays in charge.
- Give the team the exact diff, the proof, the commands run, and their output. Ask each member to approve or reject with a reason.
- Address the team's concerns, update the fix or proof when useful, and ask all three members to vote again.
- Do not present a candidate to the user as the win until the team approves it 3-0.
- After approval, run the proof one final time and give the user the result in plain English.
