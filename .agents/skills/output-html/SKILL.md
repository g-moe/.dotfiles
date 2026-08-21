---
name: output-html
description: Create a polished, self-contained HTML artifact. Use when the user wants a single `.html` file for a report, explainer, comparison, plan, visual, diagram, system walkthrough, interactive prototype, or browser-based slide deck. Use for both new artifacts and substantial rewrites. Do not use for a multi-file web app or a native presentation unless the user explicitly requests an HTML version.
disable-model-invocation: true
---

# Output HTML

Create the artifact with standard HTML, CSS, and JavaScript. Follow the behavior in this skill directly; do not assume a particular model, application, tool name, or hidden design system.

## Read first

- Read [references/html.md](references/html.md) for every artifact.
- Also read [references/presentations.md](references/presentations.md) when creating a slide deck.
- Also read [references/visuals-and-interaction.md](references/visuals-and-interaction.md) when creating a chart, diagram, timeline, technical visual, simulator, or interactive prototype.
- Do not inspect the demo unless the user requests it or a concrete implementation detail remains unclear after reading the guidance.

## Build

1. Identify the artifact's job, audience, source material, and requested output location.
2. Choose the form that matches how the artifact will be used:
   - Use a scrolling document for material meant to be read or scanned.
   - Use a slide deck for a presentation, talk, pitch, or slide-like experience.
   - Use an interactive view when controls materially improve understanding or let the user test a scenario.
   - Make a diagram the main view when relationships or flow are the subject.
3. Write a one-sentence purpose, outline the content, and choose the visual structure before styling. Decide what should be prose, a comparison, a table, a chart, a diagram, a sequence, or an interaction.
4. Verify recent, uncertain, or high-stakes claims with authoritative sources when research access is available. If it is unavailable, avoid unsupported current claims and clearly label any remaining uncertainty.
5. Create one self-contained `.html` file with embedded CSS and JavaScript. Make it work when opened directly from disk unless the requested behavior requires a network connection.
6. Use the available rendering and inspection capabilities to open the file, check realistic viewport sizes, exercise controls and keyboard behavior, inspect runtime errors, and fix problems. If rendering is unavailable, perform the strongest source and syntax checks available and do not claim visual verification.
7. Deliver the finished file through the available attachment or file-link mechanism. Always include its exact path or filename.

## Keep the output honest

- Build the requested artifact on the first screen. Do not add a cover page, app shell, sidebar, dashboard, theme toggle, or instructions unless the content needs one.
- Preserve the user's facts and intent. Tighten wording and structure without inventing substance.
- Let the subject drive the visual language. Do not force dark mode, cards, gradients, metric tiles, monospaced labels, or SVG diagrams.
- Prefer native browser features and direct code. Add libraries only when requested or when they provide a clear, substantial benefit.
- Treat interaction as part of the explanation, not decoration. Keep the artifact useful without gratuitous motion.
- Do not expose implementation notes, validation checklists, placeholder copy, or tool limitations inside the finished artifact unless the user needs that information there.

## Demo

[references/demo-cme-mes-risk-deck.html](references/demo-cme-mes-risk-deck.html) is a tested example of the quality bar. It demonstrates responsive slide staging, keyboard navigation, print output, an interactive calculator, reduced-motion support, and sourced financial facts. Do not treat its theme, layout, or subject as a template.
