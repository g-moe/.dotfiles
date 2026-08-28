---
name: gh-rebase
description: Rebase the current Git branch onto an explicit target branch with a permanent backup. Use only when the user invokes `$gh-rebase` and names the target branch in that request.
disable-model-invocation: true
---

# Rebase Rules

1. Require one exact local or remote-tracking target branch in the invocation. Do not infer it or accept a placeholder. If it is missing or ambiguous, ask for it and stop.
2. Never push. Never delete, rename, or overwrite the backup branch. Do not fetch or change the target.
3. Abort a failed rebase and restore the pre-rebase state before reporting it.
4. Always replay current-branch commits on top of the target tip.

## Workflow

1. Resolve the named current branch and `<target>^{commit}`. Stop on detached `HEAD`, an invalid target, or worktree changes that prevent rebase.
2. Review `git status --short --branch`, ahead/behind counts, commits on each side, and `git diff --stat <target>...HEAD`.
3. Save the old `HEAD` as `tmp/bak-<current-branch-name>-<UNIX-MS-TIMESTAMP>`. Stop if this branch exists. Verify it points to the old `HEAD`.
4. Run `git rebase <target>`.
5. On failure, save Git's error output, run `git rebase --abort`, and verify that no rebase is in progress, the current branch is unchanged, and `HEAD` equals the saved old `HEAD`. Report the cause, recovery result, and backup branch. Do not push.
6. On success, verify that:
   - no rebase is in progress;
   - `<target>` is an ancestor of `HEAD`;
   - the current branch name did not change;
   - the backup still points to the old `HEAD`; and
   - `git range-diff <target>...<backup> <target>...HEAD` shows no unexplained lost or changed work.
7. Report the target, old and new commit IDs, backup branch, verification result, and that nothing was pushed.
