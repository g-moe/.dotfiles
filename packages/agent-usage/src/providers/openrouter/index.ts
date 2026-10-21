import { existsSync } from "node:fs";
import { homedir } from "node:os";
import {
	asFiniteNumber,
	asJsonObject,
	asNonEmptyString,
	type JsonObject,
} from "../../domain/json.js";
import type { IProvider } from "../../domain/provider.js";
import type { UsageSnapshot, UsageSpend } from "../../domain/usage.js";
import { readJsonFile } from "../shared/files.js";
import { getJson } from "../shared/http.js";

// Reports spend for the key that authenticates the request, not the whole account.
const KEY_URL = "https://openrouter.ai/api/v1/key";

interface OpenRouterKey {
	readonly label: string;
	readonly key: string;
}

interface OpenRouterKeyUsage {
	readonly label: string;
	readonly body: JsonObject;
}

interface OpenRouterKeySource {
	readonly label: string;
	readonly path: string;
}

/**
 * List the auth files where coding agent CLIs store an OpenRouter key under `.openrouter.key`.
 */
export function getOpenRouterKeySources(
	homeDirectory: string = homedir(),
	dataDirectory: string | undefined = process.env.XDG_DATA_HOME,
): readonly OpenRouterKeySource[] {
	dataDirectory ??= `${homeDirectory}/.local/share`;
	return [
		{ label: "OpenCode", path: `${dataDirectory}/opencode/auth.json` },
		{ label: "pi", path: `${homeDirectory}/.pi/agent/auth.json` },
	];
}

/**
 * Read every stored OpenRouter key, skipping missing files and keys already seen.
 */
export function getOpenRouterKeys(
	sources: readonly OpenRouterKeySource[] = getOpenRouterKeySources(),
): readonly OpenRouterKey[] {
	const keys = new Map<string, OpenRouterKey>();

	for (const source of sources) {
		if (!existsSync(source.path)) continue;

		const document = asJsonObject(readJsonFile(source.path));
		const key = asNonEmptyString(asJsonObject(document?.openrouter)?.key);
		if (key && !keys.has(key)) keys.set(key, { label: source.label, key });
	}

	if (keys.size === 0)
		throw new Error("No OpenRouter key found; sign in with opencode or pi");

	return [...keys.values()];
}

/**
 * Compute how much of a key's spending cap is used; keys without a cap have none.
 */
function parseCapUsedPercent(data: JsonObject | undefined): number | undefined {
	const limit = asFiniteNumber(data?.limit);
	const remaining = asFiniteNumber(data?.limit_remaining);
	if (limit === undefined || limit <= 0 || remaining === undefined)
		return undefined;

	return Math.min(100, Math.max(0, (1 - remaining / limit) * 100));
}

/**
 * Map one `GET /api/v1/key` response into the spend and cap of that key.
 *
 * @example
 * parseOpenRouterSpend("pi", { data: { usage_daily: 1, usage_weekly: 2, usage_monthly: 3, limit: 20, limit_remaining: 15 } });
 * // { label: "pi", capUsedPercent: 25, todayUsd: 1, weekUsd: 2, monthUsd: 3 }
 */
export function parseOpenRouterSpend(
	label: string,
	body: JsonObject,
): UsageSpend {
	const data = asJsonObject(body.data);
	const todayUsd = asFiniteNumber(data?.usage_daily);
	const weekUsd = asFiniteNumber(data?.usage_weekly);
	const monthUsd = asFiniteNumber(data?.usage_monthly);

	if (todayUsd === undefined || weekUsd === undefined || monthUsd === undefined)
		throw new Error("OpenRouter returned invalid key usage");

	const spend = { label, todayUsd, weekUsd, monthUsd };
	const capUsedPercent = parseCapUsedPercent(data);
	return capUsedPercent === undefined ? spend : { ...spend, capUsedPercent };
}

export class OpenRouterProvider implements IProvider<
	readonly OpenRouterKey[],
	readonly OpenRouterKeyUsage[]
> {
	readonly id = "openrouter" as const;
	readonly displayName = "OpenRouter";

	_getAuth(): readonly OpenRouterKey[] {
		return getOpenRouterKeys();
	}

	async _fetchUsage(
		auth: readonly OpenRouterKey[],
	): Promise<readonly OpenRouterKeyUsage[]> {
		return Promise.all(
			auth.map(async ({ label, key }) => ({
				label,
				body: await getJson(KEY_URL, { Authorization: `Bearer ${key}` }),
			})),
		);
	}

	_parseUsage(rawUsage: readonly OpenRouterKeyUsage[]): UsageSnapshot {
		return {
			providerId: this.id,
			displayName: this.displayName,
			limits: [],
			spend: rawUsage.map(({ label, body }) =>
				parseOpenRouterSpend(label, body),
			),
		};
	}

	async getUsage(): Promise<UsageSnapshot> {
		return this._parseUsage(await this._fetchUsage(this._getAuth()));
	}
}
