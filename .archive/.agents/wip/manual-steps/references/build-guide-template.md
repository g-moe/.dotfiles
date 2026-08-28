# Build Guide Template

Use this template to create a standalone guide for a human to build or rebuild a
coding result. Replace every angle-bracket placeholder. Remove author notes and
sections that do not add useful information.

Do not copy the order in which an agent created the source work. Order the guide
for human understanding, useful decisions, working milestones, and reliable
checks.

# <Result to build>

## Build contract

### Goal

<State what the human will build or rebuild.>

### Starting point

<Describe the files, tools, knowledge, and working behavior available before S0.>

### Finished state

<Describe observable behavior and evidence that will prove the build is complete.>

### In scope

- <Included result>

### Out of scope

- <Excluded result>

### Research used

- `<source>` — <What this source established>

### Evidence limits

<List only important claims, gaps, or source behavior that could not be verified.
Remove this section when there are none.>

## Prerequisites and constraints

<Include only requirements and constraints that affect the build as a whole.
Keep requirements that matter to only one or several steps with those steps.>

- <Requirement or constraint>

## Assumptions

<Record assumptions that affect the guide. Remove this section when there are no
meaningful assumptions.>

### A1 — <Assumption>

- **Basis:** <Why the guide makes this assumption>
- **Becomes important:** <S0, S2, or another step identifier>
- **Revisit when:** <Evidence that should cause the human to reconsider it>

## Tradeoffs

<Record real choices without forcing every step to contain one. Give each choice
a breadcrumb to the steps where the human must act on it. Remove this section
when there are no meaningful tradeoffs.>

### T1 — <Decision area>

- **Options:** <The practical choices>
- **Recommendation:** <The recommended choice and why>
- **Consequences:** <What the recommendation improves, limits, or gives up>
- **Becomes actionable:** <The first affected step identifier>
- **Also affects:** <Other affected step identifiers, or "None">

## Glossary

<Define only terms whose meaning is needed to follow the guide. Remove this
section when ordinary project language is enough.>

- **<Term>:** <Meaning in this guide>

## Guide map

- S0 — <Outcome-oriented step title>
- S1 — <Outcome-oriented step title>
- M1 — <Useful milestone title>
- S2 — <Outcome-oriented step title>

---

## S0 — <Outcome-oriented step title>

### Outcome

<Describe what will exist or work after this step.>

### Why now

<Explain why this step belongs here and why later work depends on it.>

### Uses

- <Starting material, earlier step, assumption, or tradeoff>

### Decisions for this step

<Explain only choices that the human must make during this step. Link global
entries by identifier instead of repeating them. Remove this section when the
step has no real decision.>

- **Related tradeoff:** <T1>
- **Decision needed:** <What the human must choose>
- **Recommendation:** <Recommended choice and why>

### Human prompt

<Write a standalone prompt that the human can give to an implementation agent.
Limit it to this step. Include the relevant starting state, exact scope, expected
artifacts, and required checks. Do not ask the implementation agent to complete
later steps.>

> <Prompt>

### Instructions

1. <Give an exact human action.>
2. Create or open `<exact/path>`.
3. Add the following starter content:

   ```text
   <Usable code, configuration, command, or other starter content>
   ```

4. <State what the human must add, change, decide, or observe.>

### Validate

Run:

```sh
<exact command>
```

Expected result:

```text
<Observable output, behavior, or other success condition>
```

Do not continue until:

- <Required check passes>
- <Required behavior or idea is understood>

### If validation fails

- **`<symptom>`:** <Likely meaning and focused investigation>

Do not bypass, skip, or weaken <important check>.

### Leaves for later steps

- <Artifact, behavior, decision, or proof that later steps can rely on>

### Related sections

- **Depends on:** <Earlier step identifiers, or "Starting point">
- **Used by:** <Later step or milestone identifiers>
- **Related assumptions:** <Identifiers, or "None">
- **Related tradeoffs:** <Identifiers, or "None">

---

## S1 — <Outcome-oriented step title>

<Repeat the complete step structure from S0.>

---

## M1 — <Useful milestone title>

<Use a milestone only when the human can meaningfully use, inspect, understand,
or steer a coherent partial result. A milestone is not an implementation step.>

### What now works

<Describe the behavior created by the preceding steps.>

### Try it

<Give an exact command or interaction.>

```sh
<command>
```

### What to notice

- <Important behavior, connection, output, or design boundary>

### Current boundary

<Explain what does not work yet and why that is expected at this point.>

### Steering questions

- <A question that helps the human confirm or change the direction>

### Related sections

- **Demonstrates:** <Earlier step identifiers>
- **Informs:** <Later step identifiers>

---

## S2 — <Outcome-oriented step title>

<Repeat the complete step structure from S0.>

---

## Final verification

<Gather only checks needed to prove the finished result works as a whole. Do not
replace or weaken the focused checks inside individual steps.>

Run:

```sh
<exact final verification command>
```

Expected result:

```text
<Observable final success condition>
```

Confirm:

- <The finished-state claim is supported>
- <No required check was skipped>
- <Any remaining limit is stated clearly>
