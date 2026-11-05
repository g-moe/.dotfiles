---
name: output-html
description: Create a self-contained HTML page (options, comparisons, explainers, reports) from the house template. Use when the user asks for an HTML file or page.
disable-model-invocation: true
---

# Output HTML

Copy [assets/template.html](assets/template.html) and replace its content. Keep its style and script.

- Use only the components the content needs, not every one the template shows.

- Always highlight only the `TODO:` prefix of the user's TODOs with a yellow background.

- Code always goes in a `codefile` figure with its file path in the caption.

- Escape `<`, `>`, `&` in code as `&lt;`, `&gt;`, `&amp;`.

- Save where the user says; otherwise in a gitignored folder (for example `.local/`). Give the full path.

**Mobile layout.** Use the template’s single mobile breakpoint, `max-width: 640px`, for all mobile rules. Keep the built-in navigation script: it turns page navigation tabs into a hamburger menu on mobile, closes after selection or Escape, and leaves desktop tabs visible. Insert navigation before `DOMContentLoaded` fires.
