# Visual and interactive artifact instructions

Apply these instructions when the artifact contains charts, diagrams, timelines, technical visuals, simulators, calculators, or interactive prototypes.

## Contents

1. Choose the right visual
2. Charts and quantitative displays
3. Diagrams and flows
4. Timelines and sequences
5. Interactive prototypes and calculators
6. SVG and Canvas implementation
7. Validation

## 1. Choose the right visual

- Start with the question the visual must answer. Do not begin by choosing a chart or diagram style.
- Use a table when exact lookup and repeated-field comparison matter more than shape.
- Use bars for magnitude comparisons, lines for change over an ordered continuous axis, dots for compact comparison, and scatterplots for relationships between two quantitative variables.
- Use a flow or sequence diagram for movement, decisions, dependencies, or handoffs.
- Use a hierarchy or grouped system map for ownership, containment, or architecture.
- Use a timeline for ordered events and state changes across time.
- Use an interactive control when changing inputs reveals behavior that static examples cannot show efficiently.
- Skip the visual when a sentence or short aligned list is clearer.

## 2. Charts and quantitative displays

- State the measure, unit, population, and time range near the chart.
- Use a truthful scale. Start bars at zero unless a clearly labeled exception is necessary. Show axis breaks explicitly.
- Sort categorical bars when order is not intrinsic. Keep chronological and ranked orders meaningful.
- Direct-label important series and values when space allows. Use a legend only when direct labels would create clutter.
- Keep gridlines and ticks quiet. Emphasize the data and the comparison the viewer should notice.
- Use color consistently across the artifact. Limit simultaneous series colors and add line style, marker, pattern, or label differences when color alone is insufficient.
- Highlight one focus series or interval and mute context rather than making every series equally loud.
- Avoid 3D effects, perspective, decorative area, and animation that distort value perception.
- Show missing data as missing. Do not silently convert it to zero.
- Place the source and any transformation, forecast, normalization, or assumption next to the chart.
- Provide a short text takeaway and, when practical, a table or accessible summary of the underlying values.

## 3. Diagrams and flows

- Write the nodes and relationships before drawing. Remove elements that do not help answer the user's question.
- Choose a clear reading direction—usually left-to-right or top-to-bottom—and keep it consistent.
- Group related nodes with spacing, alignment, labels, and boundaries. Use containers only for real ownership or scope.
- Route connectors around nodes. Minimize line crossings, unnecessary bends, and ambiguous attachment points.
- Use arrowheads only when direction matters. Label unusual relationships directly on the connector.
- Distinguish primary flow from secondary, optional, asynchronous, or error paths through line style and labels, not color alone.
- Keep node titles short. Put longer explanation in a nearby caption, detail panel, or legend.
- Align repeated node types and keep their visual treatment consistent.
- For architecture, show system boundaries, trust boundaries, storage, external actors, and protocols only when relevant to the requested view.
- For flowcharts, use recognizable decision points and make each branch label an explicit condition or result.
- Include a legend only for symbols or line styles that are not already obvious.

## 4. Timelines and sequences

- Use a stable direction and a meaningful scale. Do not imply equal time intervals when spacing is only ordinal.
- Label dates, phases, or sequence numbers at the points where the reader needs them.
- Separate parallel tracks when different actors, systems, or workstreams progress independently.
- Show current state, completed state, and future state with both labels and visual treatment.
- Keep annotations close to the event they explain and avoid long leader lines.
- For incident or execution timelines, distinguish observation, decision, action, and result when those categories matter.

## 5. Interactive prototypes and calculators

- Define the smallest complete scenario that demonstrates the requested behavior.
- Use realistic, deterministic sample content. Clearly label illustrative, simulated, or live values.
- Make the initial state useful. Do not open on an empty shell unless emptiness is the behavior being demonstrated.
- Use native form controls, clear labels, appropriate input types, units, ranges, and steps.
- Keep a single state model. Recalculate outputs from current inputs instead of manually synchronizing duplicate values.
- Show formulas, assumptions, and included or excluded costs next to computed results.
- Handle invalid input, empty input, division by zero, minimum and maximum values, and other relevant boundaries.
- Update results at the pace the user expects. Immediate input updates suit calculators; an explicit action suits expensive or consequential operations.
- Announce important result changes through a polite live region.
- Make controls usable with keyboard, pointer, touch, and zoomed text.
- Prevent global shortcuts from taking over keys while a user edits a field.
- Provide reset only when returning to a known baseline is useful.
- Implement only the flow the prototype needs. Do not simulate a backend, authentication, routing, or persistence unless the scenario requires it.

## 6. SVG and Canvas implementation

- Use ordinary HTML and CSS for simple boxes, aligned comparisons, and flows that do not need routed connectors.
- Use inline SVG when crisp scaling, labels, connectors, coordinate placement, or print quality matter.
- Give SVG a meaningful `viewBox` and responsive width. Avoid fixed dimensions that force page overflow.
- Style repeated SVG elements with classes and CSS variables. Avoid scattering hard-coded color values through the markup.
- Use SVG text for short labels that must stay positioned with the visual. Use HTML alongside the SVG for long prose and accessible explanations.
- Define reusable markers, patterns, gradients, and filters once in `defs` when they provide a real benefit.
- Keep strokes legible at the smallest tested size. Ensure arrowheads, markers, and labels do not disappear when scaled.
- Make meaningful SVG accessible with a title, description, or adjacent explanation. Hide purely decorative SVG.
- Use Canvas for dense plots, particle systems, or high-frequency animation. Provide an accessible text or table equivalent because Canvas has no useful semantic structure by itself.
- Avoid external visualization libraries unless the requested complexity clearly justifies their weight and network or packaging cost.

## 7. Validation

- Confirm that the visual answers its intended question without relying on surrounding explanation.
- Verify every label, unit, category, value, source, and direction against the underlying content.
- Check the visual at its largest and smallest rendered sizes.
- Test long labels, missing values, zero values, negative values, ties, and extreme values when they are possible.
- Check color contrast and meaning without color. Use grayscale inspection when series distinction is important.
- Verify connectors remain attached, labels do not overlap, and responsive scaling does not make text unreadable.
- Exercise every control and boundary state. Confirm displayed results match the underlying formula or state transition.
- Check keyboard use, focus visibility, live updates, reduced motion, and console output.
- Inspect print output when the visual is expected to appear in a PDF or handout.
