# Plan Name

## Env Sync

Q: Which authentication does each strategy require?

- `development` : The developer must be logged in to both AWS and Convex on their machine.
- `deployment` : AWS authentication for the branch's AWS organization, plus a Convex deploy key obtained from AWS for the selected project and deployment strategy.

Q: Must the target Convex deployment already exist?

- `development` : Yes. The developer's Convex deployment is created when they are added to the team. Sync uses that existing deployment.
- `deployment` : No. Sync creates the target Convex deployment if it does not exist.

Q: How are the AWS organization and Convex project selected?

- Both strategies use the Git branch:
  ```text
  main      -> aws-org=prod, convex-project=tradester-prod
  staging   -> aws-org=test, convex-project=tradester-test
  otherwise -> aws-org=test, convex-project=tradester-test
  ```

Q: How is the Convex deployment selected within the project?

- `development` : Uses the developer's existing development deployment in the selected project.
- `deployment` : Uses the selected project's production deployment for `main`/`staging`, or its branch-specific preview deployment for any other branch.

Q: How are the app URLs selected?

- `development` : Uses `getAppLocalDevUrl(app)` for getflat, support, and terminal:

  ```ts
  const APP_LOCAL_DEV = {
  	getflat: { port: 5174 },
  	support: { port: 5176 },
  	terminal: { port: 5173 },
  } as const satisfies Record<AppName, { port: number }>;

  export function getAppLocalDevUrl(
  	app: AppName,
  ): `https://localhost:${number}` {
  	return `https://localhost:${APP_LOCAL_DEV[app].port}`;
  }
  ```

- `deployment` : Uses the existing `getTradesterUrls(branch)` logic unchanged. [Source](/home/linux/code/tradester/tradester-monorepo/tradester/packages/lib/src/env/env-tradester-urls.ts:17)

Q: Which runtime mode does each strategy set?

- `development` : `PUBLIC_TRADESTER_RUNTIME_MODE=development`
- `deployment` : `PUBLIC_TRADESTER_RUNTIME_MODE=production`

Q: How are Stripe webhooks and `STRIPE_WEBHOOK_SECRET` managed?

- `development` : Each Convex development deployment has its own Stripe webhook. Delete that deployment's existing webhook, if present, and create a new webhook for the same deployment using the configured Stripe API version. Write the new signing secret returned by `stripeWebhookManagement` to `STRIPE_WEBHOOK_SECRET` in that same Convex deployment.

- `deployment` : `main`/`staging`: Each Convex production deployment has its own Stripe webhook, created manually in the Stripe dashboard. Sync must never create or delete this webhook. Sync may update its URL, subscribed events, description, metadata, and enabled status; `webhookEndpoints.update` cannot update its API version. Retrieve the signing secret from AWS SSM through `fetchFromAWS` and write it to `STRIPE_WEBHOOK_SECRET` in that same Convex deployment. Throw if the required webhook or signing secret is missing.
- `deployment` : Other branches (Convex preview): Uses exactly the same webhook and signing secret behavior as `development`, applied to the selected Convex preview deployment.

Q: How is the Stripe webhook for the selected Convex deployment identified?

- `development` : Compute the backend identifier with `createIdentifier(env.PUBLIC_CONVEX_URL_CLOUD)`, using the same helper and cloud URL as the email alias logic. Match `metadata['convex-backend-id']` to that identifier. Sync sets this metadata when creating a webhook. Use the matched endpoint's Stripe-assigned `id` for webhook API operations.

  ```ts
  metadata: {
      'convex-backend-id': createIdentifier(env.PUBLIC_CONVEX_URL_CLOUD)
  }
  ```

  The identifier has the format `id_<12 hex characters>`. The helper's normalization is explicit: "Trims whitespace, lowercases the value, hashes it with SHA-256, and uses the first 12 hex chars." [Identifier source](https://github.com/tradester-official/tradester/blob/165a7cbd700e1031ec5f7d5e62244cd1e3b591be/packages/lib/src/crypto/identifier.ts#L7-L28)

  The auth rewrite's email alias logic uses: `return createEmailAlias(email, createIdentifier(secret('CONVEX_CLOUD_URL')));` [Email alias source](https://github.com/tradester-official/tradester/blob/165a7cbd700e1031ec5f7d5e62244cd1e3b591be/packages/convex/convex-backend/src/convex/_shared/users/users_sync.ts#L212-L214)

- `deployment` : Uses exactly the same identifier, metadata value, and lookup as `development`. For `main`/`staging`, the metadata must be set to this computed identifier during manual webhook setup. For other branches, sync sets the metadata when creating the preview deployment's webhook.

Q: How are potentially stale Convex environment variables handled?

- `development` : Only add or update Convex environment variables. Log only the names of existing keys absent from the `Env` schema as potentially stale. Never delete Convex environment variables.
- `deployment` : Uses exactly the same add/update behavior and logging as `development`. Never delete Convex environment variables.

Q: What does the TypeScript sync function return?

- `development` : Returns the complete resolved `Env` after a successful sync, so the caller can inject it into later child commands without fetching it again.
- `deployment` : Returns the complete resolved `Env` after a successful sync, so CI can inject it into later child commands without fetching it again.

Q: What does the control flow look like? Pseudocode with function(input): output in a call stack.

- Types:

  ```ts
  import type { EnvVar, EnvVars } from "@repo/lib/env";

  type Env = {
  	AWS_GITHUB_ROLE: EnvVar<"AWS_GITHUB_ROLE">;
  	BETA_SIGNUP_WEBHOOK_SECRET: EnvVar<"BETA_SIGNUP_WEBHOOK_SECRET">;
  	BETTERUPTIME_API_TOKEN: EnvVar<"BETTERUPTIME_API_TOKEN">;
  	COGNITO_APP_CLIENT_ID: EnvVar<"COGNITO_APP_CLIENT_ID">;
  	COGNITO_APP_CLIENT_SECRET: EnvVar<"COGNITO_APP_CLIENT_SECRET">;
  	COGNITO_AWS_ACCESS_KEY_ID: EnvVar<"COGNITO_AWS_ACCESS_KEY_ID">;
  	COGNITO_AWS_SECRET_ACCESS_KEY: EnvVar<"COGNITO_AWS_SECRET_ACCESS_KEY">;
  	COGNITO_USER_POOL_ID: EnvVar<"COGNITO_USER_POOL_ID">;
  	CONVEX_B2B_SECRET: EnvVar<"CONVEX_B2B_SECRET">;
  	CONVEX_MASTER_KEY_V1: EnvVar<"CONVEX_MASTER_KEY_V1">;
  	CONVEX_MASTER_KEY_V2: EnvVar<"CONVEX_MASTER_KEY_V2">;
  	DEV_POSTMARK_TRANSACTIONAL_API_KEY: EnvVar<"DEV_POSTMARK_TRANSACTIONAL_API_KEY">;
  	DISCORD_BOT_UPTIME_URL: EnvVar<"DISCORD_BOT_UPTIME_URL">;
  	DISCORD_CLIENT_ID: EnvVar<"DISCORD_CLIENT_ID">;
  	DISCORD_TOKEN: EnvVar<"DISCORD_TOKEN">;
  	DISCORD_WEBHOOK_STATUS_URL: EnvVar<"DISCORD_WEBHOOK_STATUS_URL">;
  	DISCORD_WEBHOOK_URL: EnvVar<"DISCORD_WEBHOOK_URL">;
  	DXFEED_API_KEY: EnvVar<"DXFEED_API_KEY">;
  	DXFEED_WEBHOOK_SECRET: EnvVar<"DXFEED_WEBHOOK_SECRET">;
  	INTERCOM_ACCESS_TOKEN: EnvVar<"INTERCOM_ACCESS_TOKEN">;
  	INTERCOM_BASE_URL: EnvVar<"INTERCOM_BASE_URL">;
  	INTERCOM_MESSENGER_SECRET: EnvVar<"INTERCOM_MESSENGER_SECRET">;
  	MAILERLITE_API_KEY: EnvVar<"MAILERLITE_API_KEY">;
  	MAIN_CONVEX_DEPLOY_KEY: EnvVar<"MAIN_CONVEX_DEPLOY_KEY">;
  	NEWS_SERVICE_CALENDAR_URL: EnvVar<"NEWS_SERVICE_CALENDAR_URL">;
  	NEWS_SERVICE_HEADLINES_URL: EnvVar<"NEWS_SERVICE_HEADLINES_URL">;
  	NINJATRADER_OAUTH_CLIENT_ID: EnvVar<"NINJATRADER_OAUTH_CLIENT_ID">;
  	NINJATRADER_OAUTH_CLIENT_SECRET: EnvVar<"NINJATRADER_OAUTH_CLIENT_SECRET">;
  	NINJATRADER_PASSWORD: EnvVar<"NINJATRADER_PASSWORD">;
  	NINJATRADER_USERNAME: EnvVar<"NINJATRADER_USERNAME">;
  	POSTMARK_TRANSACTIONAL_API_KEY: EnvVar<"POSTMARK_TRANSACTIONAL_API_KEY">;
  	PREVIEW_CONVEX_DEPLOY_KEY: EnvVar<"PREVIEW_CONVEX_DEPLOY_KEY">;
  	PROJECTX_APP_ID: EnvVar<"PROJECTX_APP_ID">;
  	PROJECTX_SECRET_KEY: EnvVar<"PROJECTX_SECRET_KEY">;
  	PUBLIC_CONVEX_URL_CLOUD: EnvVar<"PUBLIC_CONVEX_URL_CLOUD">;
  	PUBLIC_CONVEX_URL_SITE: EnvVar<"PUBLIC_CONVEX_URL_SITE">;
  	PUBLIC_DXFEED_BASE_URL: EnvVar<"PUBLIC_DXFEED_BASE_URL">;
  	PUBLIC_DXFEED_HISTORY_URL: EnvVar<"PUBLIC_DXFEED_HISTORY_URL">;
  	PUBLIC_DXFEED_IPF_URL: EnvVar<"PUBLIC_DXFEED_IPF_URL">;
  	PUBLIC_DXFEED_REALTIME_URL: EnvVar<"PUBLIC_DXFEED_REALTIME_URL">;
  	PUBLIC_GIT_BRANCH: EnvVar<"PUBLIC_GIT_BRANCH">;
  	PUBLIC_GIT_RAW_BRANCH: EnvVar<"PUBLIC_GIT_RAW_BRANCH">;
  	PUBLIC_INTERCOM_APPID: EnvVar<"PUBLIC_INTERCOM_APPID">;
  	PUBLIC_INTERCOM_DOMAIN_PREFIX: EnvVar<"PUBLIC_INTERCOM_DOMAIN_PREFIX">;
  	PUBLIC_TRADESTER_APP_URL_GETFLAT: EnvVar<"PUBLIC_TRADESTER_APP_URL_GETFLAT">;
  	PUBLIC_TRADESTER_APP_URL_STATUS_PAGE: EnvVar<"PUBLIC_TRADESTER_APP_URL_STATUS_PAGE">;
  	PUBLIC_TRADESTER_APP_URL_SUPPORT: EnvVar<"PUBLIC_TRADESTER_APP_URL_SUPPORT">;
  	PUBLIC_TRADESTER_APP_URL_TERMINAL: EnvVar<"PUBLIC_TRADESTER_APP_URL_TERMINAL">;
  	PUBLIC_TRADESTER_DOMAIN: EnvVar<"PUBLIC_TRADESTER_DOMAIN">;
  	PUBLIC_TRADESTER_LOG_LEVEL: EnvVar<"PUBLIC_TRADESTER_LOG_LEVEL">;
  	PUBLIC_TRADESTER_ORG: EnvVar<"PUBLIC_TRADESTER_ORG">;
  	PUBLIC_TRADESTER_RUNTIME_MODE: EnvVar<"PUBLIC_TRADESTER_RUNTIME_MODE">;
  	STRIPE_PUBLISHABLE_KEY: EnvVar<"STRIPE_PUBLISHABLE_KEY">;
  	STRIPE_SECRET_KEY: EnvVar<"STRIPE_SECRET_KEY">;
  	STRIPE_WEBHOOK_SECRET: EnvVar<"STRIPE_WEBHOOK_SECRET">;
  	TRADESTER_TESTING_ACCOUNT_PASSWORD: EnvVar<"TRADESTER_TESTING_ACCOUNT_PASSWORD">;
  	TRADESTER_TESTING_ACCOUNT_USERNAME: EnvVar<"TRADESTER_TESTING_ACCOUNT_USERNAME">;
  	TRADESTER_TESTING_ADMIN_ACCOUNT_PASSWORD: EnvVar<"TRADESTER_TESTING_ADMIN_ACCOUNT_PASSWORD">;
  	TRADESTER_TESTING_ADMIN_ACCOUNT_USERNAME: EnvVar<"TRADESTER_TESTING_ADMIN_ACCOUNT_USERNAME">;
  	TRADESTER_TESTING_SUPPORT_ACCOUNT_PASSWORD: EnvVar<"TRADESTER_TESTING_SUPPORT_ACCOUNT_PASSWORD">;
  	TRADESTER_TESTING_SUPPORT_ACCOUNT_USERNAME: EnvVar<"TRADESTER_TESTING_SUPPORT_ACCOUNT_USERNAME">;
  };

  type EnvFromRuntime = EnvVars<
  	| "PUBLIC_GIT_BRANCH"
  	| "PUBLIC_GIT_RAW_BRANCH"
  	| "PUBLIC_TRADESTER_APP_URL_GETFLAT"
  	| "PUBLIC_TRADESTER_APP_URL_STATUS_PAGE"
  	| "PUBLIC_TRADESTER_APP_URL_SUPPORT"
  	| "PUBLIC_TRADESTER_APP_URL_TERMINAL"
  	| "PUBLIC_TRADESTER_DOMAIN"
  	| "PUBLIC_TRADESTER_ORG"
  	| "PUBLIC_TRADESTER_RUNTIME_MODE"
  >;
  ```

- Both strategies use this call order. Function names below describe the intended responsibilities. Async calls show their resolved return type:

  ```text
  envSync({ strategy: development | deployment }): Env
  │
  ├── 1. getEnvFromRuntime({ strategy }): EnvFromRuntime
  │   ├── 1a. getGitBranchNames(): GitBranchNames
  │   │
  │   ├── 1b. getTradesterOrgForBranch({ branch: PUBLIC_GIT_BRANCH }): TradesterOrg
  │   │   ├── branch === main → prod
  │   │   └── otherwise       → test
  │   │
  │   ├── 1c. Require getAwsAuthForOrg({ org: PUBLIC_TRADESTER_ORG }): {
  │   │       arn: string | undefined;
  │   │       id: string;
  │   │       org: TradesterOrg;
  │   │       userId: string | undefined;
  │   │   }
  │   │   ├── Throws   → stop sync
  │   │   └── Succeeds → continue
  │   │
  │   ├── 1d. Derive runtime variables
  │   │   ├── strategy === development
  │   │   │   ├── Runtime mode → development
  │   │   │   └── App URLs     → getAppLocalDevUrl({ app }): `https://localhost:${number}`
  │   │   └── strategy === deployment
  │   │       ├── Runtime mode → production
  │   │       └── App URLs     → getTradesterUrls({ branch }): TradesterUrls
  │   │
  │   └── Return one EnvFromRuntime object
  │
  ├── 2. fetchEnvFromAws(): EnvFromAws
  │   ├── 2a. getAwsSsmParams(): SSMParams
  │   │   ├── Throws   → stop sync
  │   │   └── Succeeds → params
  │   │
  │   ├── 2b. Convert parameter Name/Value pairs into one values object
  │   │
  │   ├── 2c. EnvFromAwsSchema.parse(values): EnvFromAws
  │   │   ├── Throws   → stop sync
  │   │   └── Succeeds → envFromAws
  │   │
  │   └── Return envFromAws
  │
  ├── 3. fetchEnvFromConvex({ strategy, envFromRuntime, envFromAws }): EnvFromConvex
  │   ├── 3a. Select the Convex project
  │   │   ├── PUBLIC_TRADESTER_ORG === prod → tradester-prod
  │   │   └── PUBLIC_TRADESTER_ORG === test → tradester-test
  │   │
  │   ├── 3b. getConvexDeploymentStrategy({ strategy, envFromRuntime, envFromAws }): ConvexDeploymentStrategy
  │   │   ├── strategy === development
  │   │   │   └── convex-dev → developer's development deployment
  │   │   └── strategy === deployment
  │   │       ├── PUBLIC_GIT_BRANCH === main OR staging
  │   │       │   └── convex-prod → MAIN_CONVEX_DEPLOY_KEY, --prod
  │   │       └── otherwise
  │   │           └── convex-preview → PREVIEW_CONVEX_DEPLOY_KEY,
  │   │                                --preview-name PUBLIC_GIT_BRANCH
  │   │
  │   ├── 3c. Ensure the selected deployment exists
  │   │   ├── convex-prod
  │   │   │   └── Continue to 3d; production already exists
  │   │   ├── convex-dev
  │   │   │   └── Continue to 3d; the developer's deployment already exists
  │   │   └── convex-preview
  │   │       ├── getConvexEnv({ name, strategy }):
  │   │       │     value | { kind: 'isMissingDeployment' } | { kind: 'AuthorizationError' }
  │   │       │   wraps: `npx convex env get <name> --preview-name PUBLIC_GIT_BRANCH`
  │   │       ├── AuthorizationError → stop sync
  │   │       ├── value → continue to 3d
  │   │       └── isMissingDeployment
  │   │           ├── claim/create preview via claim_preview_deployment
  │   │           │   with reuse: true; do not push Convex functions
  │   │           ├── claim/create fails → stop sync
  │   │           └── claim/create succeeds → continue to 3d
  │   │
  │   ├── 3d. Read URLs from that same deployment via getConvexEnv({ name, strategy })
  │   │   ├── CONVEX_CLOUD_URL → PUBLIC_CONVEX_URL_CLOUD
  │   │   ├── CONVEX_SITE_URL  → PUBLIC_CONVEX_URL_SITE
  │   │   ├── isMissingDeployment → stop sync
  │   │   ├── AuthorizationError → stop sync
  │   │   └── other failure → stop sync
  │   │
  │   ├── 3e. EnvFromConvexSchema.parse(values): EnvFromConvex
  │   │   ├── Throws   → stop sync
  │   │   └── Succeeds → envFromConvex
  │   │
  │   └── Return envFromConvex
  │
  ├── 4. manageStripeWebhook({ strategy, envFromRuntime, envFromAws, envFromConvex }): EnvVar<'STRIPE_WEBHOOK_SECRET'>
  │   ├── 4a. backendId = createIdentifier(envFromConvex.PUBLIC_CONVEX_URL_CLOUD)
  │   │   ├── Same helper and cloud URL as the email-alias path
  │   │   ├── Trims, lowercases, SHA-256, first 12 hex → `id_<12 hex characters>`
  │   │   ├── Match Stripe endpoint where metadata['convex-backend-id'] === backendId
  │   │   └── Use the matched endpoint's Stripe-assigned `id` for webhook API ops
  │   │
  │   ├── 4b. Manage the Stripe webhook for this deployment
  │   │   ├── strategy === development
  │   │   │   OR (strategy === deployment AND isMainOrStaging(envFromRuntime.PUBLIC_GIT_BRANCH) === false)
  │   │   │   ├── Match found → delete that webhook
  │   │   │   ├── Create webhook for this deployment
  │   │   │   │   (API version, events, URL, description, enabled,
  │   │   │   │    metadata['convex-backend-id'] = backendId)
  │   │   │   ├── Create fails → throw
  │   │   │   ├── response.secret missing → throw Error('Webhook creation failed to return a secret')
  │   │   │   └── Succeeds → signing secret
  │   │   │
  │   │   └── strategy === deployment
  │   │       AND isMainOrStaging(envFromRuntime.PUBLIC_GIT_BRANCH) === true
  │   │       ├── Never create or delete
  │   │       ├── Match missing → throw Error(
  │   │       │     `Required Stripe webhook not found for convex-backend-id=${backendId}`
  │   │       │   )
  │   │       ├── May update: URL, events, description, metadata, enabled
  │   │       │   (cannot update API version via webhookEndpoints.update)
  │   │       ├── Update fails → throw
  │   │       ├── STRIPE_WEBHOOK_SECRET from envFromAws
  │   │       ├── Missing/empty → throw Error(
  │   │       │     `Required STRIPE_WEBHOOK_SECRET missing from AWS SSM`
  │   │       │   )
  │   │       └── Succeeds → that secret
  │   │
  │   └── Return EnvVar<'STRIPE_WEBHOOK_SECRET'>
  │
  └── 5. syncEnvToConvex({ strategy, envFromRuntime, envFromAws, envFromConvex, stripeWebhookSecret }): Env
      ├── 5a. Build Env
      │   ├── Merge envFromRuntime + envFromAws + envFromConvex
      │   ├── Set STRIPE_WEBHOOK_SECRET from stripeWebhookSecret
      │   │   (overrides any AWS value)
      │   ├── EnvSchema.parse(merged): Env
      │   │   ├── Throws → stop sync
      │   │   └── Succeeds → env
      │   └── Continue with env
      │
      ├── 5b. Write env to the selected Convex deployment
      │   ├── Add or update each key from env
      │   ├── Never delete Convex environment variables
      │   ├── Log only the names of existing Convex keys
      │   │   absent from Env as potentially stale
      │   ├── Write fails → stop sync
      │   └── Succeeds → continue
      │
      └── Return env
  ```

  `fetchEnvFromAws` no longer takes `EnvCtx`; AWS authentication is handled in `1c`. Pagination, decryption, parameter-name conversion, and duplicate checks remain inside `getAwsSsmParams`.
