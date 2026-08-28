---
name: tests-sync
description: Use only when the user explicitly invokes $tests-sync to inspect changed code and update or add tests without hiding runtime defects.
disable-model-invocation: true
---

# Tests Sync

## Overview

Inspect the changed code, then update or add tests to match its runtime behavior.

## Rules

If changed code, or runtime code touched while fixing tests, has a real bug, stop immediately and explain it. Do not edit runtime code unless asked.

## Steps

1. Cover the main path and useful edge cases.
2. Run the relevant tests.
3. Finish with the test files changed and commands run.
