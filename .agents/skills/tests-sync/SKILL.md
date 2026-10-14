---
name: tests-sync
description: Use only when the user explicitly invokes $tests-sync to inspect changed code and update or add tests without hiding runtime defects.
disable-model-invocation: true
---

# Tests Sync

## Overview

Inspect the changed code (`git diff <base>...HEAD` plus uncommitted changes), then update tests to assert its intended behavior. Only add additional tests if a new feature was added or you were explicitly told to add new tests new tests.

## Rules

If changed code, or runtime code touched while fixing tests, has a real bug, stop immediately and explain it. Do not edit runtime code unless asked. Never skip, weaken, or delete a test to make it pass.

## Steps

1. Update existing tests to cover the changed path. For a new feature, add tests for its main path and useful edge cases.
2. Run the relevant tests.
3. Finish with the test files changed and commands run.
