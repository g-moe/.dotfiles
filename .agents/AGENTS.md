## Rules

### Communication

- Match the scope of the request. A specific ask gets a specific result; an open-ended one gets a broader one. This applies to answers, code changes, file edits, and commands alike: a question about X is answered, not acted on; a fix for X fixes X, not its neighbors. Don't extend past the request based on what you think I'll want next.

- Read for intent, not literal wording. If my point is right but loosely phrased, agree with the point; don't correct the phrasing.

### Never

- Never fake or weaken verification. No skips, no disabled linters, no tests that accept broken behavior. Failed/Red checks stay visible. 

- Never apologize. When at fault, state the bad behavior (what), then state what led to the bad behavior (why/how).
```md
Mistake: ...
Cause: ...
```

- Never attribute yourself on a commit or PR.

## Code Style

Code is how we do a lot of communication, so it must be easy to read.

**Readability**
- Use empty lines to break up long-scoped function, method, or script blocks.
- Order files bottom-up: shared setup (module-level constants, types, instances) first, then helpers in call order, then exported entry points last. Keep values used in only one place inside the thing (function, class, html) that uses them.
- Keep cyclomatic complexity low.
- Do not nest ternaries.

**Responsibility**
- Put code where they belongs. Follow existing boundaries and naming; do not invent new terms. 

**Patterns**
- Validate data at the boundaries. This means public -> private, or external -> internal. We transform/validate data into a shape that we know. We ONLY want to interact with data in our shape and do not mix shapes.
- Use readonly types where applicable.
- Pit of success by Rico Mariani - safe behaviours happen by default so authors can't get it wrong.


### Coding Examples

1. Commenting Functions
```typescript
/**
 * Compose RGB channels into a lowercase `#rrggbb` hex color.
 * Does not validate number; each channel must be an integer from 0 to 255.
 *
 * @example
 * rgbToHex(255, 8, 128); // '#ff0880'
 * rgbToHex(0, 0, 0); // '#000000'
 */
export function rgbToHex(r: number, g: number, b: number): HEXValue {
```

2. Commenting Long Codeblock
```typescript
/** 
 * Reads local runtime metadata and verifies repository prerequisites. 
 */
export async function runSetup(summary: SummarySection[]): Promise<SetupContext> {
    const rootDir = process.cwd();
    const env = getEnvFromRuntime({ log, strategy: 'deployment' });

    // Validate dependencies
    await runCommand({
        args: ['run', 'validate:dependencies'],
        command: 'pnpm',
        cwd: rootDir,
        stepName: 'setup:validate-dependencies'
    });

    // Verify git branch exists in remote
    await runCommand({
        args: ['ls-remote', '--exit-code', '--heads', 'origin', env.PUBLIC_GIT_RAW_BRANCH],
        command: 'git',
        cwd: rootDir,
        stepName: 'setup:verify-remote-branch'
    });

    //... more code 

    return { rootDir, runCommand, summary };
}
```