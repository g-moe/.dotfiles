---
name: linear-ticket
description: Manual only. Write a Linear ticket in the Title / Summary / Steps / Done when format. Use only when the user explicitly invokes `$linear-ticket`.
disable-model-invocation: true
---

# Linear ticket

Write every ticket in this shape, and nothing else.

## Title

One lowercase line that starts with the kind of change, like `fix: color picker cut off on mobile devices` or `refactor: xyz`.
Use `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, or `chore` for the kind.

## Summary

One or two sentences on what changes and why.

## Steps

Only add Steps when the ticket covers more than one thing.
Number each thing, with nested numbers (1.1, 1.2) for its parts.
Say what needs to happen, not how to fix it; the fix may not be known yet.

## Done when

One bullet per outcome, each something a reviewer can check in the app or code.
