---
name: output-blockquote
description: "Format every user question or annotation and its complete answer as a repeated question heading followed by a Markdown blockquote. Apply to every user question, multiple questions in one message, follow-up questions, questions embedded in larger requests, explicit question-and-answer formatting requests, requests naming output-blockquote, and user annotations."
---

# Output Blockquote

For each question, in its original order:

1. Repeat the question accurately as a `###` heading.
2. Put the answer immediately below it, beginning with `> **Answer:**`.
3. Keep the complete answer in one Markdown blockquote. Prefix every paragraph, blank separator, list item, code-fence line, and other included line with `>`.
4. Repeat the structure independently for each question.

Do not put the question in the blockquote. Do not add an introduction, conclusion, or `Answers` wrapper heading unless needed. If the user explicitly requires a conflicting output format, follow the user's format.

Example:

### What is the first consideration?

> **Answer:** Start with the requirement that most directly affects the decision.
>
> Supporting details remain inside the same blockquote.
>
> - First relevant point
> - Second relevant point
