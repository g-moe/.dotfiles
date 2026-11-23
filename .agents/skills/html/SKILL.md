---
name: html
description: Use only when explicitly invoked as $html to build a self-contained HTML page or lesson course from the house template.
disable-model-invocation: true
---

# HTML

Pick the flavor from the first word of the request, then read only that flavor's reference:

- `help` → reply with the help text below and do nothing else.
- `lesson` → [references/lesson.md](references/lesson.md).
- anything else → default: do what the user asks, following [references/default.md](references/default.md). The first word is part of the request.

## Help text

```text
/html <request>                  default: any single page (options, comparison, explainer, report, demo)
/html lesson <topic and sources> a reviewed course of lessons from source material
/html help                       this list
```

## Every flavor

**Template.** Start from [assets/template.html](assets/template.html). Keep its styles and scripts. A flavor adds its own parts from its reference; it never changes the template's base styles, so every page has the same sizes and spacing.

**Self-contained.** All CSS, JavaScript and media are inline. The only network requests are the template's SHA-pinned Shiki files; without network, code shows uncolored.

**Components.** Use only the components the content needs. The template's Brainstorm tab shows each one with its markup.

- Code goes in a `figure.codefile` with its file path in the `figcaption`. Shiki colors it by the caption's file extension; set `data-lang` on the `pre` when the caption has none (for example `data-lang="bash"`).
- Escape `<`, `>`, `&` in code as `&lt;`, `&gt;`, `&amp;`.
- Put whitespace-sensitive blocks (`.cmd`, `.tree`, `.diagram`) in a `pre`, so formatting keeps their lines.
- Embed images, GIFs and video in a `figure.media` as base64 `data:` URLs. Prefer MP4 or WebM to GIF; give video `autoplay muted loop playsinline controls`. Add `phone` to the figure for phone-width shots.
- Draw callouts on a screenshot with the `.shot` SVG overlay: its `viewBox` is the image's size in pixels.
- Highlight only the `TODO:` prefix of the user's TODOs by wrapping it in `<mark>`.

**Mobile layout.** Use the template's single mobile breakpoint, `max-width: 640px`, for all mobile rules. Keep the built-in navigation script: it puts one hamburger menu in the page `<header>` on mobile, which opens every `nav` to fill the screen below the header, closes after selection or Escape, and leaves desktop tabs visible. Keep the page title as the only content of a `body > header`, with no description under it, and insert navigation before `DOMContentLoaded` fires.

**Saving.** Save where the user says.
Otherwise use `local/` at the repository root, or the repository's own folder for temporary work; outside a repository, use a temporary folder.
Do not use a folder whose name starts with a dot, such as `.local/`, because the T3 Code file viewer cannot open files inside it.
Before saving the first page in a repository, make sure git ignores `local/` without touching tracked files: append `/local/` to the file that `git rev-parse --git-path info/exclude` prints when that line is not there yet.
Never edit the repository's `.gitignore` for this.
Give the full path.
