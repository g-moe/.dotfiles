---
name: output-html
description: Create a self-contained HTML page (options, comparisons, explainers, reports) from the house template. Use when the user asks for an HTML file or page.
disable-model-invocation: true
---

# Output HTML

Copy [assets/template.html](assets/template.html) and replace its content. Keep its style and script.

- Use only the components the content needs, not every one the template shows.

- Code always goes in a `codefile` figure with its file path in the caption.

- Escape `<`, `>`, `&` in code as `&lt;`, `&gt;`, `&amp;`.

- Save where the user says; otherwise in a gitignored folder (for example `.local/`). Give the full path.
