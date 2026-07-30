---
name: output-codeblock
description: "DEPRECATED: NEVER USE"
---

<!-- WIP: "Use whenever the user asks to see, show, explain, understand, walk through, locate, or demonstrate code. Do not use this skill for code blocks that deliver an edit, patch, or a full script from a user request." -->

# Output Codeblock

1. Include commented code blocks to show and explain the requested code.
2. Explain what the block represents, why key fields or steps exist, and any non-obvious behavior.
3. Keep comments useful. Do not comment syntax that is already incredibly obvious.
4. Preserve all existing comments and make new comments additive.
5. Include necessary context.

Before sending, inspect every fenced block. Do not send until every explanatory block follows these rules.

## Example

Bad:

```js
async function runWithRetries(task, maxAttempts) {
	let lastError;

	for (let attempt = 1; attempt <= maxAttempts; attempt++) {
		try {
			return await task();
		} catch (error) {
			lastError = error;

			// Stop immediately when retrying cannot help.
			if (!isRetryable(error)) break;

			await waitBeforeRetry(attempt);
		}
	}

	reportFailure(lastError);
	throw lastError;
}
```

Good:

```js
async function runWithRetries(task, maxAttempts) {
	// Keep the latest failure so it can be reported if no attempt succeeds.
	let lastError;

	// Each pass represents one allowed attempt, including the first call.
	for (let attempt = 1; attempt <= maxAttempts; attempt++) {
		try {
			// A successful result exits the function and skips every remaining attempt.
			return await task();
		} catch (error) {
			// Save the failure before deciding whether another attempt is worthwhile.
			lastError = error;

			// Stop immediately when retrying cannot help.
			// isRetryable() owns that policy; its implementation lives outside this block.
			if (!isRetryable(error)) break;

			// The external helper applies the project's delay and backoff rules.
			// Waiting here prevents the loop from retrying immediately.
			await waitBeforeRetry(attempt);
		}
	}

	// Report only the final failure; intermediate failures may recover on a later attempt.
	// reportFailure() sends the error to the project's monitoring system.
	reportFailure(lastError);

	// This path is reached only after all attempts fail or a failure stops retries early.
	throw lastError;
}
```
