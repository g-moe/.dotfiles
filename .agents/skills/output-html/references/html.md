# HTML artifact instructions

Apply these instructions to every artifact. Adjust them when the user's request, source material, brand, or accessibility needs require a different choice.

## Contents

1. Brief and content model
2. Document structure
3. Visual direction
4. Layout and responsiveness
5. Components and data
6. Interaction
7. Accessibility
8. Self-contained implementation
9. Validation

## 1. Brief and content model

- Write one private sentence before coding: “This artifact helps [audience] understand or do [job].” Use it to decide what belongs.
- Identify the primary reading path, the most important conclusion or action, and any secondary details.
- Separate provided facts from assumptions. Verify recent, uncertain, or high-stakes claims with authoritative sources when research is available.
- Keep sources near the claims, data, or visuals they support. Use short source labels and direct links.
- Preserve the user's meaning and useful terminology. Fix grammar, remove repetition, and do not invent evidence or filler.
- Choose the right information shape:
  - Use prose for explanation and nuance.
  - Use aligned rows or a table for exact comparisons and repeated fields.
  - Use a timeline or flow for sequence and change.
  - Use a chart for quantitative relationships.
  - Use a diagram for structure, ownership, dependency, or movement.
  - Use controls only when changing an input helps answer a real question.

## 2. Document structure

- Include `<!doctype html>`, `lang`, UTF-8 charset, responsive viewport metadata, a useful title, and a short meta description.
- Use semantic landmarks: `header`, `nav`, `main`, `section`, `article`, `aside`, and `footer` where they reflect the content.
- Use one clear `h1`. Keep heading levels in a logical hierarchy and make headings describe the section's point.
- Start the first viewport with the artifact itself. Do not place an explanatory landing page in front of the requested content.
- Keep the main reading order correct in the DOM. Do not rely on CSS placement to repair a confusing source order.
- Use real lists for lists, real tables for tabular relationships, `figure` and `figcaption` for explanatory visuals, and `button` for actions.
- Put definitions, units, time ranges, filters, assumptions, and qualifications next to the content they affect.
- Keep interface text direct. Remove repeated titles, redundant labels, and instructions the layout already makes obvious.

## 3. Visual direction

- Derive the visual language from the subject and audience. Choose two or three private direction words such as precise, editorial, calm, mechanical, playful, or cinematic before styling.
- Create a small coherent system for background, surfaces, text, muted text, lines, accent, states, typography, spacing, and radius. Use CSS custom properties for values that repeat meaningfully.
- Prefer one dominant neutral family and one intentional accent. Add more colors only for real categories, series, or states.
- Reserve success, warning, and error colors for those meanings. Do not use them as neutral decoration.
- Prefer system fonts for dependable local rendering. Add another font only when it is allowed, available, and important to the requested identity.
- Establish visible type roles: display or page title, section heading, body, label, caption, and code or numeric text.
- Use fluid type with `clamp()` where it helps. Keep long-form body text near 16–20 px at common desktop sizes and use a comfortable line height around 1.45–1.7.
- Keep prose lines roughly 45–80 characters wide. Allow tables, diagrams, charts, and media to use a wider region.
- Build rhythm from a small spacing scale. Use whitespace, alignment, and rules before adding a box around each section.
- Avoid “card soup.” Add a container only when its border, background, or grouping communicates a real boundary or interaction.
- Do not add gradients, glass effects, shadows, dark mode, theme toggles, or decorative motion by default. Use them only when they support the direction.

## 4. Layout and responsiveness

- Use normal document flow first. Use Grid for two-dimensional relationships and Flexbox for one-dimensional alignment.
- Give flexible grid and flex children `min-width: 0` when they contain text or controls that must shrink.
- Prefer responsive functions such as `min()`, `max()`, `clamp()`, `minmax()`, and `repeat(auto-fit, minmax(...))` over many fixed breakpoints.
- Use absolute positioning for overlays, annotations, and staged visuals—not for ordinary document layout.
- Set a readable maximum width for prose and a separate wider maximum for dense visuals when needed.
- Reflow multi-column sections into one column before text or controls become cramped. Change composition; do not scale the whole page down.
- Keep the page free of horizontal scrolling unless it is intentionally a wide canvas. Place wide tables or diagrams in a labeled local overflow region.
- Use `overflow-wrap: anywhere` for untrusted long identifiers, URLs, and code-like labels.
- Make images and SVGs responsive. Preserve aspect ratio and prevent intrinsic media width from expanding the page.
- Keep fixed or sticky controls from covering content. Add safe padding for their occupied area.
- Verify at least one wide desktop viewport and a narrow phone-sized viewport around 360–430 px. Also inspect the breakpoint where columns change.

## 5. Components and data

- Prefer ordinary headings, lists, definition lists, tables, callouts, and figures over invented component patterns.
- Align repeated metrics and comparison fields so the eye can scan down a stable column.
- Put units in labels or column headers, not in only one data cell.
- Right-align numeric table columns when it improves comparison. Keep labels left-aligned.
- Make tables usable on narrow screens through local horizontal scrolling, selective column stacking, or a purposeful alternate layout.
- Use badges sparingly for short status or category labels. Do not turn every metadata value into a pill.
- Use icons only when they add recognition or save space. Pair unfamiliar icons with text or an accessible label.
- Use inline SVG for small essential icons or visuals when that keeps the file self-contained. Hide purely decorative SVG from assistive technology.

## 6. Interaction

- Do not add JavaScript when HTML and CSS already provide the behavior.
- Use native controls and events first. Use buttons for actions and links for navigation.
- Keep state explicit and deterministic. Derive displayed results from the current inputs rather than duplicating values across the page.
- Validate inputs, set sensible ranges and steps, and handle initial, changed, empty, invalid, and boundary states.
- Update related outputs immediately when useful. Use a polite live region for important computed results or asynchronous state changes.
- Keep keyboard and pointer behavior equivalent. Do not hide essential actions behind hover.
- Prevent keyboard shortcuts from stealing input keys when focus is inside `input`, `textarea`, `select`, or editable content.
- Provide reset or undo only when users can make meaningful reversible changes.
- Use animation to explain continuity, sequence, or causality. Keep durations short, avoid motion on every element, and honor `prefers-reduced-motion`.

## 7. Accessibility

- Use native semantics before ARIA. Add ARIA only when native HTML cannot express the needed name, role, state, or relationship.
- Give every form control an associated label and every actionable icon an accessible name.
- Provide useful alternative text for meaningful images. Use empty alternative text or `aria-hidden="true"` for decoration.
- Maintain a logical tab order. Do not use positive `tabindex` values.
- Provide clearly visible keyboard focus without relying only on color.
- Ensure text, important lines, controls, and state indicators have readable contrast in the actual rendered theme.
- Do not use color as the only carrier of meaning. Add labels, patterns, shapes, or text where needed.
- Keep touch targets large enough to use comfortably and leave room for text zoom.
- Respect reduced-motion preferences and make the full meaning available without animation.

## 8. Self-contained implementation

- Put CSS in a `style` element and JavaScript near the end of `body` unless a different placement is required.
- Avoid build steps, package managers, frameworks, and network requests for a one-file artifact unless the request requires them.
- Avoid module imports that commonly fail under `file://`. Use ordinary inline scripts for local standalone behavior.
- Inline small critical assets. For large embedded assets, consider whether the added file weight is justified.
- If external assets or data are required, document the dependency in the artifact and provide a useful local fallback when possible.
- Keep implementation proportional to the artifact. Do not build a component framework, router, state library, or token catalog for a one-off page.
- Keep code readable enough to inspect: meaningful names, grouped styles, small event handlers, and comments only where behavior is not obvious.

## 9. Validation

- Open the finished file in a browser or renderer when available. Use a temporary local static server when direct local-file access prevents accurate testing.
- Compare the rendered artifact against the brief: correct purpose, complete content, clear first viewport, and no placeholder material.
- Inspect the opening viewport, longest section, widest content, smallest text, fixed controls, and all stateful regions.
- Test every interactive control, link, keyboard path, invalid input, empty state, and boundary state that exists.
- Check the console for runtime errors and warnings. Fix the underlying problem; do not hide it.
- Verify there is no unintended clipping, overlap, horizontal page scroll, hidden focus, hover-only content, or unreadable contrast.
- Test a desktop viewport, a narrow viewport, and any critical intermediate breakpoint.
- Check print output when the artifact is meant to print or become a PDF.
- When rendering is unavailable, validate document structure and script syntax with the strongest available checks. State that visual inspection was not performed; never present source inspection as visual proof.
- Deliver the artifact through the available file or attachment mechanism and include its exact location.
