# Tradester Ops Environment Tasks

```ts
// ============================================================================
// 1. Env Sync
// Status:
// Goal: Build Env from EnvFromAws, EnvFromConvex, and EnvFromRuntime.
// ============================================================================

// ------------------------------------------------------------------------
// 1a. Create the Three Source Schemas
// ------------------------------------------------------------------------
// Status:
// Goal:
// - Create one runtime schema for each source.
// - Parse each source once and use the existing flat Env type for the result.

// Scope:
// - Create EnvFromAwsSchema, EnvFromConvexSchema, and EnvFromRuntimeSchema.
// - Do not create a fourth TradesterEnv schema.

// Example Codeblock:
import {
	createEnv,
	type EnvFromAws,
	type EnvFromConvex,
	type EnvFromRuntime,
} from "@repo/lib/env";

const EnvFromAwsSchema = createEnv<EnvFromAws>({
	client: {
		// Variables supplied by AWS.
	},

	server: {
		// Variables supplied by AWS.
	},
});

const EnvFromConvexSchema = createEnv<EnvFromConvex>({
	client: {
		PUBLIC_CONVEX_URL_CLOUD: createEnv.client.url({
			brand: "convex cloud url",
		}),
		PUBLIC_CONVEX_URL_SITE: createEnv.client.url({
			brand: "convex site url",
		}),
	},

	server: {},
});

const EnvFromRuntimeSchema = createEnv<EnvFromRuntime>({
	client: {
		// Branch, organization, Tradester URLs, and runtime mode.
	},

	server: {},
});

// Verification:
// - Each schema uses its existing type from @repo/lib/env.
// - No new type alias or complete runtime schema is added.

// ------------------------------------------------------------------------
// 1b. Get and Validate EnvFromAws
// ------------------------------------------------------------------------
// Status:
// Goal:
// - Replace getParameters with one public getAwsSsmParams function.
// - Confirm the AWS organization before each SSM read.
// - Read AWS SSM parameters and validate them as EnvFromAws.

// Scope:
// - Keep AWS authorization and SSM fetching separate internally.
// - Compose both operations in getAwsSsmParams.
// - Use EnvFromAws directly. Do not add EnvFromAwsType.
// - Do not load Convex or runtime values.

// Example Codeblock:
export async function getAwsSsmParams(
	org: EnvVar<"PUBLIC_TRADESTER_ORG">,
	log: Logger,
): Promise<SSMParams> {
	await getAwsAuthForOrg(org, log);

	const params = await fetchParameters();
	return params.sort((first, second) => first.Name.localeCompare(second.Name));
}

export async function getEnvFromAws(envCtx: EnvCtx): Promise<EnvFromAws> {
	const params = await getAwsSsmParams(envCtx.org, envCtx.log);
	const values = Object.fromEntries(
		params.map(({ Name, Value }) => [Name, Value]),
	);

	return EnvFromAwsSchema.parse(values);
}

/* Example Callstack:
    getEnvFromAws(envCtx)
    ├── getAwsSsmParams(envCtx.org, envCtx.log)
    │   ├── Confirm the AWS organization
    │   └── Read and sort AWS SSM parameters
    ├── Convert parameters to a flat record
    └── Parse the record as EnvFromAws
    */

// Verification:
// - getAwsSsmParams authenticates before it reads SSM.
// - AWS authorization failure stops before SSM access.
// - SSM failure reaches the caller.
// - getEnvFromAws converts and validates the SSM parameters.
// - Invalid AWS values fail EnvFromAwsSchema validation.

// ------------------------------------------------------------------------
// 1c. Get and Validate EnvFromConvex
// ------------------------------------------------------------------------
// Status:
// Goal:
// - Select the current Convex deployment.
// - Read and validate its cloud and site URLs as EnvFromConvex.

// Scope:
// - Use EnvFromConvex directly. Do not add EnvFromConvexType.
// - Make the Convex lookup asynchronous.

// Example Codeblock:
export async function getEnvFromConvex(
	envCtx: EnvCtx,
	envFromAws: EnvFromAws,
): Promise<EnvFromConvex> {
	const strategy = getConvexDeploymentStrategy(envCtx, envFromAws);

	const [cloudUrl, siteUrl] = await Promise.all([
		getConvexEnvValue("CONVEX_CLOUD_URL", strategy),
		getConvexEnvValue("CONVEX_SITE_URL", strategy),
	]);

	return EnvFromConvexSchema.parse({
		PUBLIC_CONVEX_URL_CLOUD: cloudUrl,
		PUBLIC_CONVEX_URL_SITE: siteUrl,
	});
}

/* Example Callstack:
    getEnvFromConvex(envCtx, envFromAws)
    ├── Select the Convex deployment
    ├── Read the Convex cloud URL
    ├── Read the Convex site URL
    └── Parse both values as EnvFromConvex
    */

// Verification:
// - Valid Convex URLs return EnvFromConvex.
// - A missing deployment throws the existing error.
// - A Convex authorization failure, including a 401 response, reaches the caller.

// ------------------------------------------------------------------------
// 1d. Create and Validate EnvFromRuntime
// ------------------------------------------------------------------------
// Status:
// Goal:
// - Create runtime values from the current branch, organization, URLs, and mode.
// - Validate the result as EnvFromRuntime.

// Scope:
// - Keep this function synchronous.
// - Do not load AWS or Convex values.

// Example Codeblock:
export function getEnvFromRuntime(envCtx: EnvCtx): EnvFromRuntime {
	return EnvFromRuntimeSchema.parse({
		...envCtx.branch,
		...getTradesterUrls(envCtx.branch.PUBLIC_GIT_BRANCH),
		PUBLIC_TRADESTER_ORG: envCtx.org,
		PUBLIC_TRADESTER_RUNTIME_MODE: getRuntimeMode(envCtx),
	});
}

/* Example Callstack:
    getEnvFromRuntime(envCtx)
    ├── Read the branch from EnvCtx
    ├── Create the Tradester URLs
    ├── Read the organization from EnvCtx
    ├── Select the runtime mode
    └── Parse the result as EnvFromRuntime
    */

// Verification:
// - Valid local values return EnvFromRuntime.
// - Invalid runtime values fail EnvFromRuntimeSchema validation.

// ------------------------------------------------------------------------
// 1e. Replace the Env Sync Callstack
// ------------------------------------------------------------------------
// Status:
// Goal:
// - Load and validate the three sources in order.
// - Combine them into the existing flat Env type.
// - Write and return only the combined Env.

// Scope:
// - Own source orchestration, composition, file writing, and the return value.
// - Do not parse the combined values through a fourth runtime schema.
// - Do not return EnvFromAws as a separate result.

// Example Codeblock:
export async function syncEnv({
	cwd,
	log,
}: Readonly<{
	cwd: string;
	log?: Logger;
}>): Promise<Env> {
	const envCtx = getEnvCtx({ cwd, log });

	const envFromAws = await getEnvFromAws(envCtx);
	const envFromConvex = await getEnvFromConvex(envCtx, envFromAws);
	const envFromRuntime = getEnvFromRuntime(envCtx);

	const env: Env = {
		...envFromAws,
		...envFromConvex,
		...envFromRuntime,
	};

	EnvFile.write(envCtx, env);

	return env;
}

/* Example Callstack:
    syncEnv({ cwd, log })
    ├── getEnvCtx({ cwd, log })
    ├── await getEnvFromAws(envCtx)
    ├── await getEnvFromConvex(envCtx, envFromAws)
    ├── getEnvFromRuntime(envCtx)
    ├── Combine the three sources as Env
    ├── EnvFile.write(envCtx, env)
    └── Return Env
    */

// Verification:
// - Env Sync calls each source in order.
// - Env Sync writes only after all source validation passes.
// - Env Sync returns the combined Env.

// ------------------------------------------------------------------------
// 1f. Remove the Old Source Names
// ------------------------------------------------------------------------
// Status:
// Goal:
// - Replace the old stored and resolved language with the new source names.

// Scope:
// - Update names used by the Env Sync flow.
// - Do not add compatibility aliases for removed names.

/* Example Mapping:
    Remove                          Replace with
    ├── EnvStored                   ├── EnvFromAws
    ├── EnvStoredShape              ├── EnvFromAws
    ├── EnvResolved                 ├── REMOVED
    ├── EnvResolvedShape            ├── REMOVED
    ├── getStoredEnv                ├── getEnvFromAws
    ├── getParameters               ├── getAwsSsmParams
    ├── resolveEnvVars              ├── getEnvFromConvex (moved, keep separate)
    │                               └── getEnvFromRuntime (moved, keep separate)
    ├── parseEnv                    └── Typed composition into Env
    └── result.stored               └── REMOVED
    */

// Verification:
// - Env Sync has no references to the removed source names.

// ------------------------------------------------------------------------
// 1g. Update Env Sync Tests
// ------------------------------------------------------------------------
// Status:
// Goal:
// - Update unit tests for each source boundary and the complete Env Sync flow.

// Scope:
// - Test Env Sync and each source boundary.
// - Do not create a fourth complete runtime schema.
// - Do not change Env Run or add environment filtering.
// - Do not create a Convex deployment inside Env Sync.
// - Do not implement deploy or CI changes in this task.

// Example Test Groups:
// - getAwsSsmParams tests.
// - getEnvFromAws tests.
// - getEnvFromConvex tests.
// - getEnvFromRuntime tests.
// - syncEnv tests.

// Verification:
// - getAwsSsmParams authenticates before it reads and sorts SSM parameters.
// - AWS authorization failure stops before SSM access.
// - An SSM failure reaches the caller.
// - getEnvFromAws returns parsed EnvFromAws.
// - Invalid AWS values fail EnvFromAwsSchema validation.
// - getEnvFromConvex returns parsed EnvFromConvex.
// - A missing Convex deployment throws the existing error.
// - A Convex authorization failure, including a 401 response, reaches the caller.
// - getEnvFromRuntime returns parsed EnvFromRuntime.
// - Invalid runtime values fail validation.
// - syncEnv combines, writes, and returns Env.
// - A source failure reaches the caller and prevents the environment file write.
```

```ts
// ============================================================================
// 2. Env Run
// Status:
// Goal: Keep the existing runtime behavior.
// ============================================================================

// Scope:
// - Update env-run.node.test.ts to use EnvCtxFixture.
// - Replace the manual EnvCtx with EnvCtxFixture.
// - Remove parseEnvVar.
// - Remove createTestEnv from @repo/lib/env/testing.
// - Use a small mocked EnvFile.read result.
// - Keep the existing Env Run runtime code unchanged.
// - Do not add filtering. See section 2a.

/* Example Flow:
    package.json
    └── "dev": "tradester env run -- turbo run dev"
        └── Env Run reads the synced environment file
            └── Turbo inherits the environment
                └── Each consumer process inherits the complete environment
    */

// Verification:
// - The existing Env Run tests use EnvCtxFixture and a mocked EnvFile.read result.
// - Env Run continues to pass the complete environment to the child process.
```

```ts
// ============================================================================
// 2a. Env Run with Filtering
// Status:
// Goal: Do not add filtering to Env Run.
// ============================================================================

// Scope:
// - Give the complete Env to each build or development process.
// - Let each consumer select and validate its own environment.
// - Protect client bundles through each consumer environment schema.
// - Do not require process-level environment isolation.

/* Example Flow:
    Env Run
    └── Pass the complete Env to the child process
        └── Consumer selects and validates its environment
            └── Client schema prevents server variables from entering the client bundle
    */

// Verification:
// - No filtering changes are required.
```

```ts
// ============================================================================
// 3. Env Debug
// Status:
// Goal: Keep Env Debug and compare raw AWS parameter names with EnvFromAwsSchema.
// ============================================================================

// Scope:
// - Do not create a runtime key array from the Env type.
// - Do not call Env Sync from Env Debug.
// - Do not print SSM parameter values.

// ------------------------------------------------------------------------
// 3a. Keep the Existing Command
// ------------------------------------------------------------------------
// Status:
// Goal:
// - Keep Env Debug for stale or misplaced AWS SSM parameters.

// Scope:
// - Inspect raw SSM parameter names.
// - Do not use parsed EnvFromAws values because EnvFromAwsSchema.parse removes unknown keys.

// Verification:
// - Env Debug can find unknown AWS SSM parameter names.

// ------------------------------------------------------------------------
// 3b. Replace the Global ENV Schema
// ------------------------------------------------------------------------
// Status:
// Goal:
// - Compare raw AWS SSM parameter names with EnvFromAwsSchema.shape.

// Scope:
// - Use getAwsSsmParams for the authorized SSM read.
// - Sort stale parameter names before output.

// Example Codeblock:
import { getAwsSsmParams } from "./aws/ssm/parameters.js";
import { EnvFromAwsSchema } from "./env-from-aws.js";

export async function debugEnv({ cwd, log }: DebugEnvOptions) {
	const envCtx = getEnvCtx({ cwd, log });

	const params = await getAwsSsmParams(envCtx.org, envCtx.log);
	const configuredNames = new Set(Object.keys(EnvFromAwsSchema.shape));

	const staleNames = params
		.map(({ Name }) => Name)
		.filter((name) => !configuredNames.has(name))
		.sort((first, second) => first.localeCompare(second));

	log.info(`Stale AWS parameters not in EnvFromAws (${staleNames.length}):`);
	staleNames.forEach((name) => log.info(`  ${name}`));
}

/* Example Callstack:
    tradester env debug
    ├── Create EnvCtx
    ├── Get authorized AWS SSM parameters with getAwsSsmParams
    ├── Read configured names from EnvFromAwsSchema.shape
    └── Print AWS names that are not owned by EnvFromAws
    */

// Verification:
// - Env Debug prints only stale or misplaced parameter names.
// - Env Debug prints names in sorted order.

// ------------------------------------------------------------------------
// 3c. Keep EnvFromAwsSchema Internal
// ------------------------------------------------------------------------
// Status:
// Goal:
// - Let Env Debug use the EnvFromAwsSchema runtime shape.

// Scope:
// - Export EnvFromAwsSchema from its Tradester Ops module.
// - Do not export EnvFromAwsSchema from @repo/lib/env or a public package barrel.

// Verification:
// - Env Debug imports EnvFromAwsSchema from the Tradester Ops module.
// - The public environment package does not export EnvFromAwsSchema.

// ------------------------------------------------------------------------
// 3d. Update the Existing Command Test
// ------------------------------------------------------------------------
// Status:
// Goal:
// - Update the Env Debug command test for the new AWS source boundary.

// Scope:
// - Replace the getStoredEnv mock with one getAwsSsmParams mock.
// - Return configured, stale, and misplaced names from the SSM mock.

// Verification:
// - Only stale and misplaced names are printed in sorted order.
// - Env Sync does not run.
// - Environment-file writing does not run.
```

```ts
// ============================================================================
// 4. Env Print
// Status:
// Goal: Remove Env Print with no deprecation command.
// ============================================================================

// Scope:
// - Delete the command implementation and its dead code.
// - Remove command consumers.
// - Remove agent consumers.
// - Do not update the Env skill or other environment documentation.

// Example List:
// - Delete tradester-ops/src/env/env-print.ts.
// - Delete getEnvMapText and its private formatting helpers with env-print.ts.
// - Delete tradester-ops/src/env/__tests__/env-print.node.test.ts.
// - Remove the getEnvMapText import from tradester-ops/src/cli/env/commands.ts.
// - Remove the print command block from tradester-ops/src/cli/env/commands.ts.
// - Remove print from the expected environment command names in
//   tradester-ops/src/cli/__tests__/commands.node.test.ts.
// - Remove env print from required session initialization in AGENTS.md.
// - Add packages/lib/src/env/env-config.ts as an optional AGENTS.md resource.
// - Remove the env print allowance from the AGENTS.md .env file rule.

// Verification:
// - Do not add verification work for this removal.
```

```ts
// ============================================================================
// 5. Env Auth — No Changes
// Status:
// Goal: Keep the current Env Auth behavior.
// ============================================================================
```

```ts
// ============================================================================
// 6. Dev, Build, Preview, Lint
// Status:
// Goal: Plan the environment changes for these commands.
// ============================================================================

// Scope:
// - Apply the plan to the complete repository and all Turbo tasks.
```

```ts
// ============================================================================
// 7. CI — TODO: Not Planned Yet
// Status:
// Goal: Plan the environment flow for CI deploy operations.
// ============================================================================

// Scope:
// - Apply the plan to the complete repository and all Turbo tasks.
// - Create or verify the required Convex preview deployment before Env Sync.
// - Keep Convex deployment creation outside Env Sync.

/* Example Flow:
    CI caller
    ├── Create or verify the required Convex preview deployment
    └── Call Env Sync
    */

// Verification:
// - Define CI verification when section 7 is planned.
```
