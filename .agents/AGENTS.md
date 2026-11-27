## Rules

### Communication

- Match the scope of the request. A specific ask gets a specific result; an open-ended one gets a broader one. This applies to answers, code changes, file edits, and commands alike: a question about X is answered, not acted on; a fix for X fixes X, not its neighbors. Don't extend past the request based on what you think I'll want next.

- Read for intent, not literal wording. If my point is right but loosely phrased, agree with the point; don't correct the phrasing.

- Lead with the point in one plain sentence. Then ground it: name the concrete thing I already know (code, file, behavior, term), say what is different or must change and why in one clause, and end with something exact I can check (signature, name, value, command, quote).

- Use only words from everyday speech, our code, or our glossaries. Any other term gets replaced with what it means in plain words. 

- When a task is done, reply with only what needs my action (failures, decisions, blockers). If nothing needs my action, reply `Done.` No summaries, tables, or lists of completed work.

- Don't rely on text alone; paragraph after paragraph buries the point. Give one short paragraph, then show the thing itself, so I can skip the paragraph and still get it:

  | The question is about                         | Show                                       |
  | --------------------------------------------- | ------------------------------------------ |
  | how something looks (layout, spacing, states) | a rendered mock in T3 Code, one per option |
  | how something flows (screens, steps, data)    | a rendered diagram in T3 Code              |
  | how code behaves or is structured             | code, mixed with explanation               |
  | names, types, or APIs                         | code                                       |

  A mock or diagram should explain itself, the way good code needs no comments: label options and nothing else, and if it needs notes to be understood, redraw it instead.
  For options, show each one the same way, with its trade-off.
  When a task is done, show nothing; I read the diff myself.

- When showing code, show enough (the full function or flow, with file path) that it stands on its own, and add what the code alone can't show (why it happens, what connects to what, trade-offs). Do not use 1-2 line codeblock snippets; they make replies too choppy to read. When a reply uses blocks, the code goes inside the block it belongs to.

- Use collapsed `<details>` blocks to tuck away what is not the main point, not as the default reply shape. Keep the main point, the answer, and anything I must act on in plain text outside every block. Put side notes, background, long code, and other supporting detail in a block only when it would crowd the main point. Most replies need no blocks. Steps and options are the exception: when a reply walks through steps or presents options, give each step or option its own block, and every one gets a block so they all look the same. The `<summary>` holds a bold label and one line saying what it is and why; code, commands, and detail go inside.

- When the parts are steps, write them procedurally: number the labels in order, with nested numbers (2.1, 2.2) for sub-steps. When the parts are options, letter the labels (A, B, C). Numbers are only for steps.

### Never

- Never fake or weaken verification. No skips, no disabled linters, no tests that accept broken behavior. Failed/Red checks stay visible. 

- Never apologize.

- Never attribute yourself on a commit or PR.

## Code Style

Code is how we do a majority of our communication, so it must be easy to read. The following are my preferences and the default. When working in other repos, fit their existing styles, conventions, and rules where they have them.

**Readability**
- Use empty lines to break up long-scoped function, method, or script blocks. Group together relevant code in "chunks" and add a top-line comment to narrate the long scope (see coding comment example below).
- Keep cyclomatic complexity low.
- Do not nest ternaries.
- No magic values (numbers, strings, etc).
- No code golf.
- In comments and documentation, put one sentence per line. Never break a sentence across lines to fit a width.
- Prefer object parameters instead of multiple positional parameters...an exception would be using positional args when in the hot-path.

**Responsibility**
- Put code where they belongs. Follow existing boundaries and naming; do not invent new terms. 

**Naming**
- Name things after the data they hold or the action they take, the same way at every layer: a wrapper and what it wraps use the same name for the same action and the same data.
- Name siblings by one pattern: pieces that do the same job side by side (two caches, the functions that fill them, the methods that read them) share every word except the data word.
- Before adding a sibling, copy the existing one's names and swap only the data word; if the names don't line up in a table, rename until they do.

**File Structure**
- Name files in kebab-case, starting with their folder's word and then what's inside (`check/check-todos-changes.ts`), so a file name reads correctly outside its folder.
- Use suffixes to say what kind of file it is or where it runs: `.types.ts`, `.utils.ts`, `.registry.ts`, and a runtime on tests (`.node.test.ts`, `.browser.test.ts`, `.jsdom.test.ts`, `.fixture.test.ts`).
- Put tests in a `__tests__/` folder that mirrors the source folder, so `src/time/time-parts.ts` is tested in `src/time/__tests__/time-parts.node.test.ts`.

**Patterns**
- Prefer procedural code with locality of behavior: a function reads top to bottom as commented steps, all at the same level of detail. Give a step its own function when it needs more detail than its neighbors or is reused. Don't extract just to make the caller shorter.
- Validate data at the boundaries. We transform/validate data once at the boundary into a shape that we know. We ONLY want to interact with data in our shape and do not mix shapes.
- Use readonly types and data structures where applicable.
- Pit of success by Rico Mariani - safe behaviours happen by default so authors can't get it wrong.

**Comments**

Code carries meaning through names, constants, and types, not comments.
Only these three comments are allowed; write no other kind, and drop any other kind you copy or move.

1. Doc block on a function or class: what it does, what callers must know that the signature can't say, and an `@example`.
2. Step comment: one line above each chunk of a long function, naming the step in a procedural manner.
3. Why comment: why code is shaped oddly, or a link to the algorithm it implements.

Any other comment is replaced by code:

| The comment would say                  | Write instead                       |
| -------------------------------------- | ----------------------------------- |
| what a constant, variable, or field is | a name that says it, unit included  |
| what a line does                       | nothing; the code says it           |
| what a condition means                 | a named variable or function        |
| what a special return value means      | a type, like `number \| undefined`  |


### Coding Examples

1. Doc Block (comment kind 1)
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
    ...
}
```

2. Doc Block with Links to Docs/Resources (comment kind 1)
```typescript
/**
 * Send a single transactional email through Postmark.
 * Does not retry; the caller handles a rejected promise (network failure or a non-2xx status).
 *
 * API: `POST https://api.postmarkapp.com/email`
 * Auth: `X-Postmark-Server-Token` header
 *
 * @see {@link https://postmarkapp.com/developer/api/email-api#send-a-single-email Postmark API: Send a single email}
 *
 * @example
 * const receipt = await sendPostmarkEmail({
 *     from: 'support@tradester.com',
 *     htmlBody: '<p>Your order was filled.</p>',
 *     subject: 'Order filled',
 *     to: 'trader@example.com'
 * });
 * receipt.messageId; // 'b7bc2f4a-e38e-4336-af7d-e6c392c2f817'
 */
export async function sendPostmarkEmail(params: SendPostmarkEmailParams): Promise<PostmarkEmailReceipt> {
    ...
}

```

3. Step Comments in a Long Function (comment kind 2)
```typescript
/**
 * Reads local runtime metadata and verifies repository prerequisites.
 *
 * Steps:
 * 1. Validate dependencies
 * 2. Verify git branch exists in remote
 * 3. ...
 *
 * @example
 * const context = await runSetup(summary);
 * context.rootDir; // '/home/user/tradester'
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

4. Why Comment (comment kind 3)
```typescript
// Update each row's PnL
// - A plain loop, not `.map`: this runs on every tick, and `.map` makes a new array each time.
for (let index = 0; index < rows.length; index += 1) {
    rows[index].pnl = toPnl({ row: rows[index], price });
}
```

5. Not Allowed

```typescript
// Increment the retry count
retryCount += 1;

// Map orders to their ids
const orderIds = orders.map((order) => order.id);

// Default timeout of 5 seconds
const DEFAULT_TIMEOUT_MS = 5_000;

/** Lowest take profit or stop loss in whole ticks. */
export const BRACKET_MIN_WHOLE_TICK_EXIT = 1;

// Retry when the exchange rejected the order and attempts remain
if (order.status === 'rejected' && order.rejectSource === 'exchange' && attempt < MAX_ATTEMPTS) {
    ...
}

// Returns -1 when the symbol has no trades
function getLastTradeTimeMs(symbolId: MdSymbolId): number {
    ...
}
```

6. Naming
```typescript
// Name after the data it holds: an id is `symbolId`, the full object is `symbol`
const symbolId: MdSymbolId = '/ES:XCME';
const symbol: MdSymbol = MdSymbols.get(symbolId);

// Put the unit in the name when the type doesn't carry it
const lastTradeTimeMs = symbol.lastTradeTimeMs;
const DEFAULT_FONT_SIZE_PX = 12;

// Domain words, not vendor or tool words
const dataPlan: DxfeedDataPlan = 'CMEGROUP'; // not `sub` or `feed`
await runInfraPostDeploy(context); // not `runCdkPostDeploy`

// The namespace carries the domain word; names inside it don't repeat it
import * as Uptime from '@repo/lib/domain/uptime';
const groups = Uptime.GROUPS; // not `Uptime.UPTIME_GROUPS`

// Add a qualifier once a sibling exists
import { OrdersHistoryView, OrdersOpenView } from '@core/trading'; // was `OrdersView`
```

7. Matching Names Through Wrappers
```typescript
// md-types.ts
export type MdSymbolId = string & { readonly __brand: 'MdSymbolId' };

export type MdSubscribeArgs = {
    readonly symbolId: MdSymbolId;
    readonly onFrame: (frame: MdFrame) => void;
};

// md-client.ts
export class MdClient {
    reconnect(): Promise<void> {
        return this._provider.reconnect();
    }

    subscribe({ symbolId, onFrame }: MdSubscribeArgs): () => void {
        return this._provider.subscribe({ symbolId, onFrame });
    }
}

// dxfeed-provider.ts
export class DxfeedProvider implements MdProvider {
    reconnect(): Promise<void> {
        return this._connection.reconnect();
    }

    subscribe({ symbolId, onFrame }: MdSubscribeArgs): () => void {
        return this._connection.subscribe({ symbolId, onFrame });
    }
}

// dxfeed-connection.ts
export class DxfeedConnection {
    async reconnect(): Promise<void> {
        this._socket.close();
        await this._socket.connect(this._endpoint);
    }

    subscribe({ symbolId, onFrame }: MdSubscribeArgs): () => void {
        const product = toDxfeedProduct(symbolId);
        return this._feed.addSubscription({ product, onEvent: onFrame });
    }
}
```

8. Matching Names Across Siblings
```typescript
// dom-ladder.ts
// Two caches doing the same job differ only in the data word: `PriceText` and `Pnl`
export class DomLadder {
    private readonly _priceTextByTickIndex = new Map<number, string>();
    private readonly _pnlByTickIndex = new Map<number, DomPnl | undefined>();

    private _getPriceText(tickIndex: number): string {
        ...
    }

    private _getPnl(tickIndex: number): DomPnl | undefined {
        ...
    }
}

// Not: `_priceTexts` next to `_rowPnls`, or `_toPriceText` next to `_getRowPnl`
```