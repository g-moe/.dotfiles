---
name: demo
description: Use only when the user explicitly invokes $demo to create, simplify, revise, or review an instructional software demo.
disable-model-invocation: true
---

# Demo

Create a small, working demo that teaches from first principles.

## Rules

- Assume no prerequisite knowledge unless the user states it.
- Teach the underlying system before the abstraction that wraps it.
- Explain why the system and API work that way. Do not only describe syntax.
- Keep one clear path from setup to observable result.
- Keep the target API visible. Do not hide it behind a demo abstraction.
- Remove types, helpers, state, models, and UI that do not teach the target.
- Define a technical term before using it to explain another concept.
- Add console output when inputs and results help the lesson.
- Verify real behavior. Do not weaken checks because the work is a demo.

## Workflow

### 1. Define the lesson

- State what the reader must understand after using the demo.
- Find the knowledge the reader needs before the first API call.
- Select one realistic happy path. Add an edge case only when it teaches a necessary boundary.

### 2. Inspect the real system

- Read the public API, implementation notes, and nearby examples.
- Separate what the underlying system does from what the abstraction adds.
- Identify only the system rules that shape this example. Do not import concerns from earlier demos.

### 3. Build the minimum

- Prefer `define → run → observe → clean up`.
- Use direct calls to the target API.
- Keep state only when the demo needs it to show a result.
- Prefer fixed example data over factories, counters, or generated data.

### 4. Add the walkthrough

Before an important section or call, explain:

1. What concept the reader needs.
2. Why the concept or constraint exists.
3. What the underlying system will do.
4. What the abstraction changes or hides.
5. What result the reader should observe.

Log concrete inputs, returned values, state changes, and cleanup in code order. Use the repository-approved console method.

```ts
// IndexedDB keeps data after a reload. Opening is asynchronous because the
// browser might read from disk or wait for another tab to finish an upgrade.
// This wrapper converts native request events into a Promise connection.
const database = await idb.open();

// The browser maintains this account index during writes. That costs storage
// and write work, but it avoids reading every record and filtering in JavaScript.
const rows = await Array.fromAsync(
	store.index("byAccount").ranges.only("SIM-1"),
);
console.info("Rows found through the account index:", rows);
```

### 5. Verify and prune

- Run the narrow checks that prove the demo works.
- Read the code from top to bottom as a beginner.
- Remove anything that does not teach, run, display, or verify the target.
- Report failed or unavailable checks.

## Avoid

- Restating the next line of code in a comment.
- Assuming the reader knows the system behind the abstraction.
- Adding named types or generic helpers only to make the demo look complete.
- Explaining what happens without explaining why.
- Teaching every feature when one coherent path proves the concept.
- Adding comments or logs that do not change what the reader understands.
