---
name: lesson
description: Use only when explicitly invoked as $lesson to build self-contained HTML lessons or courses from source material.
disable-model-invocation: true
---

# Lesson

Turn source material into a course a reader can learn from without opening anything else. Teach only the topic, sources and scope the user approved. If the scope is unclear, agree on it before drafting.

## Course shape

- **Page:** one HTML file holding one or more groups.
- **Group:** a run of related lessons, shown as a pill above the tabs.
- **Lesson:** one `<section>`, shown as one tab.

Give each group enough lessons to cover the approved scope, and stop there. Split a lesson when its goal needs more than about six new concepts.

A multi-page course ends with a **capstone** page that follows one concrete example through the whole topic, start to finish. Write it after every other page is finished. It must read on its own and goes through every review phase like a group.

## The page

**Self-contained.** All CSS and JavaScript are inline, and the page makes no network requests, so it works opened from disk or hosted alone. Copy in the code and facts a lesson relies on. When a page builds on another page, open with a short recap of what it needs.

**Template.** Start from [assets/template.html](assets/template.html). It holds the page shell and styles; you supply the body, the navigation script and the widgets. Use its classes for these blocks, and style the blocks it lacks to match:

| Block | Class |
| --- | --- |
| Table of contents | `.toc` |
| "By the end" box | `.learn` |
| Code switch | `.switch` |
| Quoted code with its file path | `.file` above a `pre` |
| Printed output | `pre.out`, or `pre.err` for errors |
| Note | `.note` |
| "Reader asks" box | `.ask` |
| Widget | `.widget` |
| Exercise | `.exercise` |
| Next button | `.next` |
| Warning, key idea, table, diagram | none yet |

Escape `<`, `>` and `&` inside code as `&lt;`, `&gt;` and `&amp;`.

**Navigation.** Build it from each section's `data-nav`, `data-group` and `title` attributes: one tab per lesson, plus group pills when a page holds more than one group.

**Build.** Each lesson lives in its own file containing one `<section>`, and each group's widgets live in their own script file. A small build script inserts the sections, in order, and the widget scripts into a copy of the template. Separate files let subagents work in parallel without editing the same file.

## A lesson

Every lesson follows this order:

1. A short table of contents.
2. One or two paragraphs naming the problem this lesson solves.
3. A "by the end" box listing what the reader will know.
4. Four to seven teaching sections. Prefer headings that are questions a reader would ask ("Why can't I just use an array?"); use a task heading for step-by-step procedures. Place one to three "reader asks" boxes, each right after the passage that would prompt its question.
5. One exercise, with the solution hidden until opened.
6. A wrap-up of three to five bullets.
7. A next button. On a page's last lesson, it returns to the page's first lesson.

Pages never link to each other, since each must work alone. In a multi-page course, the first lesson of each page names the other pages by title and says which to read first.

**Widgets.** Add a small plain-JavaScript simulation when stepping through state or changing an input makes an important idea clearer, such as values filling a fixed-size buffer while the oldest drop out. A widget has:

- a one-line hint;
- controls that fit (buttons, a slider or an input) and a reset;
- a visual of the current state;
- one sentence explaining what the last action did.

It must behave like the real thing for the idea being taught. If it simplifies, say so beside it.

## Voice

- Use short sentences, plain words, and "you".
- Open each section with the problem, then the idea, then the example. When it helps, show the obvious approach first and why it falls short.
- Give each paragraph one idea. After an example that introduces several new things, walk through it step by step.
- Bold each technical term at its first use on a page, and define it before relying on it. Use the topic's own names. If the topic uses one word for two things, flag it in a warning box and make the meaning clear wherever it could be confused.
- Explain why things are designed as they are. Use documented reasons where they exist; label a reason inferred from the implementation as an inference.
- Keep each section to its heading. Move a fact that doesn't answer it to the section where it does.
- Refer to earlier ideas by name, never by lesson number ("as lesson 9 shows").
- State facts directly. Don't narrate your process ("we ran a test", "the docs say").
- Cut filler ("simply", "just", "powerful") and em dashes.

## Correctness

- **Quotes are exact.** Record the source file of every quotation. When the source is a code repository, the build script compares each quoted line with that file and fails on any mismatch.
- **Examples run.** Label each example you write as runnable, a fragment or pseudocode. Run every runnable one and confirm the page shows its real output.
- **Results are reproducible.** Show the inputs and enough steps for the reader to reproduce every calculated result. Take constants and measured values from the source material.
- **Absolutes carry their conditions.** Every "always", "never", "only" or "every" states when it holds.
- **Exercises have one correct conclusion.** The reader can solve each one from what the page has taught so far, and every reasonable reading reaches the same result. Include every fact the result depends on. Ask one question, don't reuse a worked example with new numbers, and say in the solution what counts as correct when several answers are equally right.

## Process

Run independent assignments in parallel, up to the number of agents available. Brief every subagent with the exact lesson files it may edit (assignments never overlap), what the reader has already learned, and what to report back.

Start every reviewer in a fresh context holding only its brief and the files it may read. Reviewers read the built page in order, so they judge each group knowing everything before it, and never see the source material unless their phase says so.

1. **Draft.** One writer per group studies its part of the source and writes that group's lessons and widgets. You write the build script.
2. **Clarity read.** For each group, a reader with only the lessons reports where they got lost: terms used before definition, skipped steps, open questions and contradictions. The writer revises every passage the reader couldn't follow.
3. **Accuracy audit.** For each group, an auditor checks every claim, number and widget against the source, and a second fresh reader repeats the clarity read. The writer fixes every wrong or misleading claim and unclear passage, and reports anything left unresolved with the reason.
4. **Focus edit.** Edit one lesson yourself as the model of clear, focused writing for this course. Editors, each assigned different lessons, then apply the same edit to the rest.
5. **Learner check.** One subagent per about five lessons answers each exercise before opening its solution, then compares. It recomputes every result and fixes, in its assigned lessons, anything wrong, unclear or unanswerable.
6. **Blind solve.** For each group, a reader gets the built page with every solution removed, solves every exercise and reproduces every printed result, and only then receives the solutions. Fix every exercise they couldn't solve, every one where they reached a different valid result, and every result they couldn't reproduce. Rerun the blind solve on the changed lessons until it finds nothing.
7. **Re-audit.** An auditor re-checks every claim, example, result and widget changed in phases 4 to 6 against the source.
8. **Final check.** Build every page, open each from disk in a browser, and click every tab, solution and widget control, including reset. Confirm there are no console errors or network requests, and that the page reads well at phone width.

## Delivery

Show the user nothing until the final check passes. Report any problem you can't resolve instead of hiding it. Finish with links to the pages, then only the decisions the user must make and any bugs found in the source material.
