---
name: output-blockquote
description: "Format every user question as a repeated heading followed by one or more visibly spaced Markdown blockquotes."
---

# Output Blockquote

For each question, in its original order:

1. Repeat it accurately as a `###` heading.
2. Put the answer immediately below it, beginning with `> **Answer:**`.
3. Keep short answers in one Markdown blockquote.
4. Split long answers into separate Markdown blockquote sections at clear topic changes.
5. Put a standalone, unquoted `&nbsp;` line between blockquote sections, with a normal blank line above and below it.
6. Begin each later blockquote section with a bold section label when a label helps identify the topic.
7. Use a line containing only `>` between normal paragraphs within the same section.
8. Do not use `<br>` or ordinary blank lines to create space between sections.
9. Prefix every paragraph, list item, table line, code-fence line, and other line inside a blockquote section with `>`.
10. Before responding, verify that each intended visual section is a separate blockquote and that every pair of sections has an unquoted `&nbsp;` line between them.
11. Repeat the structure independently for each question.

Do not put the question inside the blockquote. Do not add an introduction, conclusion, or `Answers` wrapper heading unless needed. If the user explicitly requires a conflicting output format, follow the user’s format.

Example:

### What is the first consideration?

> **Answer:** Start with the requirement that most directly affects the decision.
>
> Supporting details remain grouped with the opening answer.

&nbsp;

> **Key points**
>
> - First relevant point
> - Second relevant point

&nbsp;

> **Additional context**
>
> Add longer supporting material in a separate visual section.
