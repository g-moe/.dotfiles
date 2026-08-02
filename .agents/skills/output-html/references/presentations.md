# HTML presentation instructions

Apply these instructions in addition to `html.md` when the artifact is a slide deck.

## Contents

1. Presentation brief
2. Narrative and slide plan
3. Slide composition
4. Type and density
5. Stage implementation
6. Navigation and state
7. Responsive behavior
8. Motion, media, and interaction
9. Accessibility
10. Print and export
11. Validation

## 1. Presentation brief

- Identify the audience, setting, time available, desired takeaway, and decision or action the deck should support.
- Write the ending first: state what the audience should believe, understand, or do after the last slide.
- Choose an aspect ratio. Use 16:9 by default for a screen presentation; use another ratio only when the display, print target, or user requires it.
- Decide whether the deck is presenter-led, self-guided, or both. Presenter-led slides can be leaner; self-guided slides need more visible context.
- Gather facts, data, sources, images, and required brand constraints before laying out slides.

## 2. Narrative and slide plan

- Create a slide outline before writing HTML. Give every slide one sentence describing its job.
- Build a deliberate arc. A useful default is:
  1. Establish the subject and promise.
  2. Show the problem, tension, or question.
  3. Explain the relevant mechanism or evidence.
  4. Present the answer, recommendation, or demonstrated behavior.
  5. Resolve implications, tradeoffs, or next decision.
  6. Close with the main takeaway.
- Change that arc when the content needs a tutorial, chronology, comparison, demo, or status sequence.
- Remove slides that repeat a previous point. Split slides that contain two competing points.
- Use assertion titles when possible: write the takeaway, not merely the topic.
- Keep citations and qualifications on the slide that relies on them.
- Do not force a target slide count. Let the story determine the length.

## 3. Slide composition

- Build one dominant composition per slide. Avoid turning the deck into a sequence of dashboards or equal-weight card grids.
- Use a consistent safe area. A useful starting point is 4–7% of the viewport width on the sides and enough top and bottom space for stable navigation.
- Establish a clear visual entry point, supporting evidence, and takeaway.
- Use whitespace and alignment to direct attention. Do not fill empty areas merely to make a slide look busy.
- Choose a composition that fits the point:
  - Statement slide: one short assertion and one supporting line or visual.
  - Comparison slide: aligned columns with the same fields and scale.
  - Evidence slide: chart or exhibit first, conclusion and source nearby.
  - Process slide: ordered steps with clear direction and current position.
  - Architecture slide: labeled regions, nodes, and routed connections.
  - Demo slide: visible controls, scenario, result, and what changed.
  - Closing slide: one memorable takeaway, decision, or action.
- Prefer one meaningful chart, image, or diagram over several small decorative visuals.
- Keep recurring furniture—brand, section label, slide number, progress, navigation—quiet and stable.
- Do not place important content under fixed navigation or close to viewport edges.

## 4. Type and density

- Design for presentation distance, not laptop reading distance.
- At a 1280×720 or similar 16:9 viewport, use these as starting ranges rather than hard rules:
  - Main title: roughly 48–80 px.
  - Slide title: roughly 36–60 px.
  - Body: roughly 22–32 px.
  - Labels and captions: generally no smaller than 14–18 px.
- Keep titles to one or two lines when possible. Reword or split the slide before reducing the title excessively.
- Keep paragraphs short. Prefer a few strong lines, an annotated visual, or a compact list over a wall of text.
- Aim for roughly three to six list items. If every item needs a paragraph, use multiple slides or a self-guided document.
- Use `clamp()` to preserve hierarchy across realistic presentation sizes, but set minimums that remain readable.
- Keep numeric and chart labels large enough to read without zoom. Direct-label important values when practical.
- Never solve overflow by scaling down the entire slide or shrinking all typography. Cut, recompose, or split the content.

## 5. Stage implementation

- Treat the deck as a stateful presentation, not a long webpage with card-like sections.
- Give each slide a semantic `section`, a stable `id`, and a heading used as its accessible name.
- Keep exactly one active slide exposed to interaction and assistive technology. Hide or inert inactive slides so their controls cannot receive focus.
- Fit one complete slide inside the desktop presentation viewport. Use a stable composition or aspect ratio without revealing adjacent slides.
- Keep the desktop stage from scrolling. If content does not fit, revise the slide.
- Use ordinary DOM and CSS for text-heavy slides. Use inline SVG for crisp diagrams and Canvas only for dense plotted data or animation that SVG cannot handle well.
- Keep one authoritative current slide index. Derive visibility, navigation state, progress, count, and URL from it.
- Initialize from a valid URL hash when present. Clamp invalid or out-of-range slide numbers.
- Avoid a framework for simple deck state. A small navigation function and event handlers are usually sufficient.

## 6. Navigation and state

- Provide visible previous and next controls unless the user requests kiosk-only output.
- Support these keyboard controls:
  - Arrow Right, Page Down, and Space: next slide.
  - Arrow Left and Page Up: previous slide.
  - Home: first slide.
  - End: last slide.
- Do not intercept keys used inside `input`, `textarea`, `select`, or editable content.
- Disable the previous control on the first slide and the next control on the last slide. Do not wrap around unless explicitly requested.
- Provide a quiet current-slide indicator such as `04 / 12` and, when useful, clickable progress markers with accessible names.
- Store the current slide in the URL hash when practical so refresh and direct links preserve position.
- Keep hash navigation, visible controls, keyboard navigation, and direct progress navigation synchronized.
- After navigation, move focus to the new slide's heading using `tabindex="-1"` or announce the slide change through an appropriate live region.
- Keep focus outlines on interactive controls. A programmatically focused heading may use a quiet focus treatment if a large outline harms the composition.

## 7. Responsive behavior

- Test the intended presentation viewport first, then a smaller laptop viewport.
- At desktop presentation sizes, keep the entire active slide visible with no internal scroll.
- Recompose multi-column slides at smaller widths: reduce gaps, simplify nonessential decoration, stack columns, or hide decorative visuals.
- If a narrow device cannot preserve the slide composition, allow the active slide to scroll vertically rather than making text unreadably small.
- Keep fixed navigation reachable and prevent it from covering the last content. Add bottom padding equal to the controls' occupied space.
- Hide nonessential fixed legal text or furniture at narrow widths when the same information exists in the content.
- Prevent horizontal page scrolling. Give an intentionally wide diagram or table its own labeled overflow region.
- Confirm that a scrollable active slide still supports keyboard navigation without trapping the user.

## 8. Motion, media, and interaction

- Use a short transition only when it helps preserve location or continuity between slides.
- Avoid animating every title, bullet, or chart by default. Reveal sequences only when order matters to the explanation.
- Honor `prefers-reduced-motion` and make all information available without animation.
- Use images, video, and audio only when they carry information or create the requested emotional tone. Do not add stock imagery as filler.
- Provide captions, controls, and alternatives for media when needed.
- Keep interactive calculations deterministic and show the formula, assumptions, units, and boundary conditions near the result.
- Keep demo data realistic but clearly distinguish illustrative values from live or sourced data.
- Make the presentation usable without network access unless the requested media or data requires it.

## 9. Accessibility

- Give the deck a clear title and each slide a unique heading.
- Expose only the active slide to the accessibility tree when practical.
- Make all navigation and slide interactions keyboard-operable.
- Give icon-only controls accessible names and visible focus.
- Use a live region for a changing slide count or computed result when the change would otherwise be missed.
- Preserve reading order inside each slide. Do not use visual placement to disguise a confusing DOM order.
- Keep charts, diagrams, and media understandable through labels, captions, summaries, or an adjacent data table.
- Do not rely on color alone for current state, series identity, or success and failure.

## 10. Print and export

- Add print styles when the deck may become a PDF or handout.
- Use an appropriate page size, such as `@page { size: 16in 9in; margin: 0; }` for a 16:9 deck.
- In print, expose every slide, place one slide on each page, and use `break-after: page`.
- Remove navigation controls, progress controls, fixed browser-only furniture, hover affordances, and interactive-only hints.
- Preserve important backgrounds and colors with print color adjustment when supported.
- Make interactive results print in a meaningful initial or current state. Do not leave an empty control shell in the PDF.
- Check that sources, captions, and legal text are not clipped in print.

## 11. Validation

- Inspect every slide, not only the first and last.
- Test the intended presentation size, a smaller laptop size, and any breakpoint that changes composition.
- Check the densest slide, longest title, widest visual, smallest label, and any slide with fixed controls or media.
- Navigate first-to-last and last-to-first with visible controls and keyboard controls.
- Test direct hash loading, refresh, invalid hashes, first-slide boundaries, and last-slide boundaries.
- Exercise every input and interactive result. Test empty, invalid, minimum, maximum, and changed values where relevant.
- Confirm there is exactly one active slide, inactive controls cannot receive focus, and focus moves predictably after navigation.
- Check for clipping, unexpected scroll, adjacent-slide leakage, covered content, horizontal overflow, and unreadable text.
- Inspect console errors and warnings and fix their causes.
- Print or preview the deck and verify one complete slide per page.
