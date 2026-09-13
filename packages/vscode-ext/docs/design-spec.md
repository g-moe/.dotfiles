# better-vscode / better-errors

## Purpose

`better-vscode` is the parent extension package.

`better-errors` is the first feature domain inside it. Its job is simple: let the user copy the current editor error into an LLM-ready prompt without rewriting or prettifying the raw diagnostic.

## Locked Decisions

- Main inspiration: `Error Lens`
- Primary action name: `Copy Error`
- Preserve the full raw diagnostic message
- Do not special-case or prettify TypeScript errors in v1
- Use VS Code diagnostics as the baseline data source
- Keep the extension language-agnostic at the core
- Organize code by feature domain, with shared contracts at the top level

## Product Shape

The core user flow is:

1. User places the cursor on a diagnostic.
2. User triggers `Copy Error`.
3. The extension reads the active diagnostic.
4. The extension builds an LLM-ready prompt that includes the raw error and local context.
5. The prompt is copied to the clipboard.

The value is speed and fidelity.

- Speed: one action from squiggle to clipboard
- Fidelity: preserve the raw full error exactly as provided by the diagnostic source

## Data Source

Primary source:

- `vscode.languages.getDiagnostics(document.uri)`

This should provide the baseline diagnostic payload:

- message
- range
- severity
- source
- code
- related information when available

Optional later enrichment:

- `vscode.executeHoverProvider`
- `vscode.executeCodeActionProvider`
- `vscode.executeDefinitionProvider`
- `vscode.executeTypeDefinitionProvider`

These are not required for v1.

## Prompt Requirements

The copied output should include:

- a short instruction for the LLM
- file path
- language
- diagnostic range
- severity
- source and code when available
- the full raw diagnostic message
- selected code when useful
- a local code window around the diagnostic
- related diagnostic information when available

Current direction: use a hybrid format.

- short natural-language instruction at the top
- structured metadata block
- raw error block
- code block

## UI Direction

The user-facing action is `Copy Error`.

For v1, the safest surfaces are:

- command registration
- editor menu/context menu entry

Important constraint:

We should not design around mutating the built-in TypeScript hover UI directly. If we want hover-adjacent UI later, it should be implemented through our own extension surfaces.

## Architecture

Recommended structure:

```text
src/
  shared/
    contracts/
    consts/
  better-errors/
    diagnostics/
    prompting/
    ui/
```

Guidelines:

- `shared/contracts/` contains shared cross-domain types
- `shared/consts/` contains shared constants and identifiers
- `better-errors/diagnostics/` resolves and normalizes editor diagnostics
- `better-errors/prompting/` builds the clipboard prompt from raw diagnostic input
- `better-errors/ui/` owns commands and user-facing interactions

Feature-specific types should stay close to the feature unless they are clearly shared across domains.

## Open Questions

1. Should `Copy Error` ship only as a command/menu action in v1, or do we also want a hover-adjacent affordance immediately?
2. What exact prompt template do we want as the default clipboard output?
3. How much local code context should be included by default?
4. Should related diagnostics always be included, or only when explicitly requested?
5. Do we want a second mode later for copying multiple diagnostics from a selection or file?
