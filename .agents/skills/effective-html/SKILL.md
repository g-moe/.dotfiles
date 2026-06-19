---
name: effective-html
description: Create a self-contained, polished HTML artifact in the effective HTML style. Use when the user wants one HTML file for a report, explainer, comparison, deck, prototype, implementation plan, visual plan, architecture diagram, stack diagram, system walkthrough, or other artifact that benefits from strong visual structure, dense but readable layout, and optional SVG-first diagrams.
---

# Effective HTML

Create a single self-contained HTML file that is visually organized, pragmatic, and easy to inspect. Use the bundled examples for style, density, alignment, interaction patterns, and tone.

## Reference Selection

Review only the references needed for the requested artifact:

- For general reports, explainers, comparisons, decks, prototypes, PR writeups, status reports, and implementation plans, review representative files in `references/html-effectiveness/`.
- For architecture, stack, system, or flow diagrams, review SVG-heavy examples in `references/html-effectiveness/` and also review `references/architecture-example.html`.
- For plan pages, keep the writing close to the user's wording, clean up grammar, and use the plan-oriented examples in `references/html-effectiveness/`.

Use `rg` or file names to pick examples by artifact type instead of loading every reference.

## Output Guidance

- Build the actual artifact as the first screen, not a landing page explaining the artifact.
- Prefer one self-contained HTML file with embedded CSS and JavaScript.
- Keep prose useful and compact. Use the visual structure to make the subject click quickly.
- Match the artifact type: plans should be pragmatic and simple; diagrams should be light on prose and diagram-first; general artifacts should balance polish with clarity.
- For diagrams, build a high-quality SVG. Style SVG elements through CSS classes and variables, not hard-coded colors inside the SVG.
- Treat proof, validation, check, runtime-check, and evidence panels as informational components: use `--accent` for borders/key lines and `--accent-soft` for subtle fills. Do not use `--success`, `--warning`, or `--error` on the container unless the whole component is explicitly a pass, warning, or failure state; use semantic status colors only for specific rows, badges, or markers inside it.
- Add interaction or animation when it helps explain state, flow, sequence, comparison, or system behavior.

## Theme Requirements

Always include dark mode:

- Use hand-rolled CSS variables on `:root` and `html.dark`.
- Use the canonical color tokens below. Use `:root` for the light variant and `html.dark` for the dark variant. Keep color variables limited to this canonical design-system set.
- Reserve `--success` and `--success-soft` for confirmed success, pass, completion, or positive-delta states only. Reserve `--warning` and `--warning-soft` for explicit caution states only. For neutral emphasis, proof paths, validation/check containers, category tags, avatars, chart series, and "next" columns, use `--accent`, `--accent-soft`, `--line`, `--line-soft`, or `--surface2`.
- Add an apply-before-paint script in `<head>` that defaults to `prefers-color-scheme`.
- Add a small theme toggle button.
- Persist the selected theme in `localStorage`.

```css
:root {
  --bg: #fdfdfd; --surface: #fdfdfd; --surface2: #f4f4f9;
  --text: #050607; --body: #262838; --muted: #7c7d8d;
  --line: #d9daec; --line-soft: #d9daec8e;
  --accent: #656675; --accent-soft: rgba(101,102,117,0.10);
  --success: #26b933; --success-soft: rgba(54,251,72,0.12);
  --warning: #bc9720; --warning-soft: rgba(255,211,98,0.16);
  --error: #aa2624; --error-soft: rgba(170,38,36,0.12);
}

html.dark {
  --bg: #050607; --surface: #101316; --surface2: #262838;
  --text: #fdfdfd; --body: #d9daec; --muted: #7c7d8d;
  --line: #262838; --line-soft: #2628388e;
  --accent: #7c7d8d; --accent-soft: rgba(124,125,141,0.14);
  --success: #65fb6e; --success-soft: rgba(101,251,110,0.16);
  --warning: #ffd362; --warning-soft: rgba(255,211,98,0.16);
  --error: #aa2624; --error-soft: rgba(170, 38, 36, 0.534);
}
```

## Typography Requirements

Use system-default font stacks. Avoid serif or decorative display fonts unless the user explicitly asks for that style.

```css
:root {
  --sans: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  --mono: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
}
```

Use `var(--sans)` for headings, body, controls, captions, and labels. Use `var(--mono)` only for code, IDs, metrics, and compact technical labels.
