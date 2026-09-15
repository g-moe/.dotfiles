# better-vscode

Private VS Code extension for terminal focus and diagnostic copying.

## Commands

- **better-vscode: terminal - focus**: reuse or create the owned terminal,
  move it to editor group 1, pin it first, focus its input, and preserve the
  maximize state tracked by the extension.
- **better-vscode: workbench - toggle maximize editor group**: toggle and track
  the active editor group's maximize state.
- **better-errors: Copy Error**: copy the editor diagnostic into a prompt.
- **better-errors: Toggle Enabled**: turn diagnostic tools on or off.

Terminal commands preserve other tabs, shells, and sidebar visibility.
Keep terminal names unique so the extension can identify its tab.
A closed shell is replaced on the next call.

## Install

From the repository root:

```bash
npm run install:vscode-ext
```

Then run **Developer: Reload Window**. Installation builds and installs the
extension only. It does not run tests or change the editor application.

## Development

From this directory, use `npm run compile` to build and `npm test` to test.
Public command IDs live in `src/commands.ts`. Feature code and tests live under
`src/features/`; shared code lives under `src/shared/`. See
[browser tests](tests/browser/README.md) for UI checks.
