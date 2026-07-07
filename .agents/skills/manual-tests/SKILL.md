---
name: manual-tests
description: Manual only. The user invokes this skill.
---

# Manual Tests

## Overview

Inspect the changed code, then update or add tests to match its runtime behavior.

## Rules

If changed code, or runtime code touched while fixing tests, has a real bug, stop immediately and explain it. Do not edit runtime code unless asked.

## Steps

Cover the main path and useful edge cases. Run the relevant tests. Finish with the test files changed and commands run.
