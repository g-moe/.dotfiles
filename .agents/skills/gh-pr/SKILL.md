---
name: gh-pr
description: Manual only. Create or update the pull request for the current branch. Use only when the user explicitly invokes `$gh-pr`.
disable-model-invocation: true
---

# Workflow

1. Use the `gh` CLI to find an open pull request for the current working branch.
2. Read the branch diff and commits. Ground the write-up in the diff. Use commit messages only when they resolve confusion or uncertainty. Infer the intent of the pull request from the diff and branch name.
3. Read the repository pull request template and relevant contribution instructions. Follow the repository conventions for the pull request title, base branch, and body. If the repository has no pull request template, write a clear body that summarizes the change and its verification.
4. Complete every template section that applies. Remove or leave unchecked what does not apply.
5. Review the title and body. Use clear, plain, everyday language, as one co-worker explains the work to another.
6. If an open pull request exists, use it. Update its body in place. Do not create a second pull request. If it is not a draft, convert it to a draft.
7. If no open pull request exists, create one with the repository conventions. Always create it as a draft.
8. Confirm that the pull request is a draft. If draft creation or conversion fails, report the failure. Do not mark the pull request as ready for review.

# Best Practices

- Link directly to commits, files, or external resources only when the link helps the reader.
- Do not replace an existing pull request title unless the user asks or the title does not follow a clear repository convention.
