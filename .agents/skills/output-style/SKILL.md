---
name: output-style
description: Apply one named output style to the user's request. Use only when the user manually invokes $output-style with a style name.
---

# Output Style

Find the style name anywhere in the manual invocation.

| When                                                   | Use                                                            |
| ------------------------------------------------------ | -------------------------------------------------------------- |
| The invocation contains `box`                          | [references/box.md](references/box.md)                         |
| The invocation contains `flowchart`                    | [references/flowchart.md](references/flowchart.md)             |
| The invocation contains `input-output`                 | [references/input-output.md](references/input-output.md)       |
| The invocation contains `before-after`                 | [references/before-after.md](references/before-after.md)       |
| The invocation contains `anatomy`                      | [references/anatomy.md](references/anatomy.md)                 |
| The invocation contains `section` or `section-divider` | [references/section-divider.md](references/section-divider.md) |
| The invocation contains `tree`                         | [references/tree.md](references/tree.md)                       |

If the style is missing, unknown, or ambiguous, list the styles in the table and ask the user to select one.

## Apply

1. Read the matching reference.
2. Apply that style to the output for the user's request.
