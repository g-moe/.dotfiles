---
name: output-html
description: Create a self-contained HTML page (options, comparisons, explainers, reports) from the house template. Use when the user asks for an HTML file or page.
disable-model-invocation: true
---

# Output HTML

Copy [assets/template.html](assets/template.html) and replace its content. Keep its style and script.

- One tab per option or topic. Only the content the user asked for.
- Code in `<pre>` gets GitHub light highlighting automatically. Escape `<`, `>`, `&` as `&lt;`, `&gt;`, `&amp;`.
- Save where the user says; otherwise in a gitignored folder (for example `.local/`). Give the full path.
