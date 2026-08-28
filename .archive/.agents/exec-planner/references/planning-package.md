# Planning Package Reference

This reference defines the required package contents and final response. Read it before drafting artifacts.

## Required Artifact Set

Create:

    specs/<feature-slug>/
    ├── 00-review-guide.md
    ├── 01-executive-summary.md
    ├── 02-current-system.md
    ├── 03-requirements.md
    ├── 04-research.md
    ├── 05-options-and-tradeoffs.md
    ├── 06-proposed-design.md
    ├── 07-interfaces-and-data.md
    ├── 08-validation.md
    ├── 09-implementation-plan.md
    ├── 10-risks-and-open-questions.md
    └── README.md

## Artifact Requirements

### `README.md`

Act as the package index. Include the feature name, one-paragraph purpose, planning status, an artifact table with links and descriptions, recommended review order, last research date, important blockers, and the definition of when the plan is approved.

Include a short consistency report containing:

- Requirements without validation
- Tasks without requirements
- Interfaces with unresolved ownership
- Remaining blockers
- Overall readiness: `Not ready`, `Ready after answers`, or `Ready for implementation`

### `00-review-guide.md`

Include decisions that need human approval, a five-minute review path, a full review path, a review checklist, sections with the highest uncertainty, how reviewers should record feedback, and these approval states:

- Draft
- Needs answers
- Approved with follow-ups
- Approved for implementation

### `01-executive-summary.md`

Include the problem, intended users, user-visible outcome, why this matters, recommended design, scope, explicit non-goals, main tradeoff, main risks, success measures, and decisions required from reviewers. Make it understandable without the rest of the package.

### `02-current-system.md`

Document the current system using repository evidence. Include current behavior, relevant components, entry points, data flow, control flow, state changes, existing interfaces, important tests, existing failure handling, constraints imposed by the current design, and a relevant file and symbol index.

Include a Mermaid diagram when three or more components interact and a diagram is clearer than prose. For example:

    flowchart LR
        A["Client"] --> B["API handler"]
        B --> C["Service"]
        C --> D["Database"]
        C --> E["Event publisher"]

### `03-requirements.md`

Separate requirements from implementation choices. Include the product goal, actors, primary user journey, secondary journeys, functional requirements with stable IDs such as `FR-001`, quality requirements with stable IDs such as `QR-001`, security and privacy requirements, accessibility requirements when applicable, compatibility requirements, acceptance scenarios, edge cases, out-of-scope behavior, assumptions, and open questions.

Use this acceptance form when suitable:

    Given <starting condition>
    When <event or action>
    Then <observable result>

Every requirement must be specific enough to test or review.

### `04-research.md`

Include questions investigated, repository findings, existing patterns, outside research, sources, conflicting evidence, unknowns, and conclusions that affect the design.

Use this table where useful:

| Question | Finding | Evidence | Confidence | Design effect |
|---|---|---|---|---|
| ... | ... | ... | High/Medium/Low | ... |

Distinguish `FACT`, `INFERENCE`, `ASSUMPTION`, and `OPEN QUESTION`. Do not describe unverified claims as facts.

### `05-options-and-tradeoffs.md`

Describe at least two credible design options. For each option, include its summary, architecture, main flow, repository changes, benefits, costs, risks, failure modes, migration needs, testing needs, and when it would be the best choice.

Include:

| Area | Option A | Option B | Option C |
|---|---|---|---|
| Repository fit | | | |
| User experience | | | |
| Complexity | | | |
| Performance | | | |
| Reliability | | | |
| Security | | | |
| Migration risk | | | |
| Maintenance | | | |
| Reversibility | | | |

End with the recommended option, decision reasons, rejected options, and conditions that would change the recommendation. Avoid fake alternatives created only to make the recommended design look better.

### `06-proposed-design.md`

Describe the selected design in enough detail for another agent to implement it. Include design goals, architecture overview, component responsibilities, end-to-end flow, important state transitions, concurrency behavior, failure handling, retry and timeout behavior, permissions and trust boundaries, observability, performance effects, compatibility strategy, migration and rollout, rollback, repository files expected to change, and repository files expected to be created.

Include pseudocode for logic with meaningful branching, ordering, retries, transactions, concurrency, or state changes. Pseudocode must describe intent rather than a specific programming language, name important inputs and outputs, show failure paths and transaction/concurrency boundaries, match the interfaces described elsewhere, and avoid pretending unresolved details are decided.

Example style:

    function processRequest(input, actor):
        validate(input)
        authorize(actor, input.resource)

        existing = repository.findByKey(input.key)

        if existing is complete:
            return existing.result

        transaction:
            record = repository.createOrLock(input.key)
            result = performOperation(input)
            repository.markComplete(record, result)
            eventQueue.enqueue(ResultCreated(result.id))

        return result

Include Mermaid sequence or state diagrams when they clarify real behavior.

### `07-interfaces-and-data.md`

Document proposed boundaries and contracts, as applicable: public APIs, internal function signatures, events, commands, database changes, schemas, state models, configuration, feature flags, permission checks, error shapes, versioning, and compatibility rules.

Use concrete examples such as:

    createWidget(
        actor: Actor,
        request: CreateWidgetRequest
    ) -> Result<Widget, CreateWidgetError>

    {
      "name": "Example",
      "mode": "safe"
    }

For each interface, identify the producer, consumer, validation, authorization, errors, compatibility expectations, and requirement IDs served. Do not claim examples are final production syntax unless the plan has enough evidence to make that decision.

### `08-validation.md`

Explain how implementation will be proven correct. Include acceptance mapping, unit tests, integration tests, end-to-end tests, contract tests, migration tests, security checks, performance checks, failure-injection cases, manual review cases, observability checks, rollback validation, exact commands when known, and expected results.

Provide:

| Requirement | Design section | Planned test | Evidence of success |
|---|---|---|---|
| FR-001 | ... | ... | ... |

Include happy paths, boundary cases, invalid input, partial failure, retries, concurrency, and recovery when relevant. Tests must assert required behavior; do not propose skipped tests or tests that accept broken behavior.

### `09-implementation-plan.md`

Use the OpenAI ExecPlan idea: make this self-contained, outcome-focused, and usable by an implementation agent without this conversation.

Include purpose and observable outcome, starting repository state, prerequisites, milestones, dependency order, concrete file-level work, required interfaces, validation after each milestone, safe stopping points, migration order, rollout order, recovery or rollback, final acceptance, and documentation updates.

For each milestone, provide its goal, requirements covered, files likely affected, symbols/components likely affected, detailed work, dependencies, validation, expected observable result, risks, and whether work can run in parallel.

Use stable task IDs such as:

    M1-T1
    M1-T2
    M2-T1

Each task must link to one or more requirement IDs, a design section, and a validation step. Tasks must be small enough for an implementation agent to complete and verify without interpreting broad phrases such as “add backend support.” Do not include calendar estimates unless explicitly requested.

### `10-risks-and-open-questions.md`

Include the risk register, open questions, assumptions, dependencies, compatibility concerns, security concerns, operational concerns, decisions deferred until implementation, decisions that block implementation, and a suggested owner for each question when it can be inferred.

Use:

| ID | Type | Description | Impact | Likelihood | Mitigation or answer needed | Blocks implementation? |
|---|---|---|---|---|---|---|
| ... | ... | ... | ... | ... | ... | Yes/No |

Separate blockers from questions that can safely remain open.

## Cross-Artifact Quality Rules

Before finishing, confirm that:

- Every requirement has a stable ID.
- Every proposed component serves at least one requirement.
- Every implementation task points to a requirement and design section.
- Every requirement has a validation method.
- Interfaces use consistent names across all files.
- Pseudocode matches the proposed interfaces and data model.
- Diagrams match the written design.
- The recommended option matches the implementation plan.
- Rejected options are not accidentally included in tasks.
- Risks have mitigations or explicit acceptance.
- Assumptions are not presented as confirmed facts.
- Blocking questions are easy to find.
- The plan does not contain hidden implementation work.
- No production files were changed.

Do not mark the plan ready if material contradictions or blockers remain.

## Final Chat Response

After writing and checking the artifacts, respond in chat using only this format:

    Planning package created: `specs/<feature-slug>/`

    Review order:
    1. [Executive summary](...)
    2. [Options and tradeoffs](...)
    3. [Proposed design](...)
    4. [Validation](...)
    5. [Implementation plan](...)

    All artifacts:
    - [Review guide](...)
    - [Executive summary](...)
    - [Current system](...)
    - [Requirements](...)
    - [Research](...)
    - [Options and tradeoffs](...)
    - [Proposed design](...)
    - [Interfaces and data](...)
    - [Validation](...)
    - [Implementation plan](...)
    - [Risks and open questions](...)
    - [Package index](...)

    Readiness: <Not ready | Ready after answers | Ready for implementation>

    Blocking questions:
    - <question or "None">

    Production code changed: No
