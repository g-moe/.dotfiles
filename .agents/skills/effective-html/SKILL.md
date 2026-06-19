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
- Add interaction or animation when it helps explain state, flow, sequence, comparison, or system behavior.

## Theme Requirements

Always include dark mode:

- Use hand-rolled CSS variables on `:root` and `html.dark`.
- Add an apply-before-paint script in `<head>` that defaults to `prefers-color-scheme`.
- Add a small theme toggle button.
- Persist the selected theme in `localStorage`.
