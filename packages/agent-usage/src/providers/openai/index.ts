import { existsSync } from "node:fs";
import { homedir } from "node:os";
import {
	asFiniteNumber,
	asJsonArray,
	asJsonObject,
	asNonEmptyString,
	type JsonObject,
} from "../../domain/json.js";
import type { IProvider } from "../../domain/provider.js";
import {
	parseDateTime,
	parseUsedPercent,
	type UsageLimit,
	type UsageResetCredit,
	type UsageSnapshot,
} from "../../domain/usage.js";
import { readJsonFile } from "../shared/files.js";
import { getJson } from "../shared/http.js";

const CREDITS_URL =
	"https://chatgpt.com/backend-api/wham/rate-limit-reset-credits";
const USAGE_URL = "https://chatgpt.com/backend-api/wham/usage";

interface OpenAIAuth {
	readonly accessToken: string;
	readonly accountId?: string;
}

interface OpenAIRawUsage {
	readonly usage: JsonObject;
	readonly credits?: JsonObject;
}

function getAuthFilePath(): string {
	const configured = process.env.CODEX_HOME;
	const paths = configured
		? [`${configured}/auth.json`]
		: [`${homedir()}/.config/codex/auth.json`, `${homedir()}/.codex/auth.json`];
	const path = paths.find(existsSync);
	if (!path) throw new Error("Codex is not signed in");
	return path;
}

function getOpenAIAuth(): OpenAIAuth {
	const root = asJsonObject(readJsonFile(getAuthFilePath()));
	const tokens = asJsonObject(root?.tokens);
	const accessToken = asNonEmptyString(tokens?.access_token);
	if (!accessToken)
		throw new Error("Codex subscription credentials are unavailable");
	const accountId =
		asNonEmptyString(tokens?.account_id) ?? asNonEmptyString(root?.account_id);
	return accountId ? { accessToken, accountId } : { accessToken };
}

function parseOpenAILimit(
	label: string,
	value: JsonObject | undefined,
): UsageLimit | undefined {
	const usedPercent = parseUsedPercent(value?.used_percent);
	if (usedPercent === undefined) return undefined;
	const absoluteReset = parseDateTime(value?.reset_at);
	const relativeSeconds = asFiniteNumber(value?.reset_after_seconds);
	const resetsAt =
		absoluteReset ??
		(relativeSeconds === undefined
			? undefined
			: new Date(Date.now() + relativeSeconds * 1_000));
	return resetsAt ? { label, usedPercent, resetsAt } : { label, usedPercent };
}

export function parseOpenAIUsage(body: JsonObject): readonly UsageLimit[] {
	const rateLimit = asJsonObject(body.rate_limit);
	const primary =
		asJsonObject(rateLimit?.primary_window) ?? asJsonObject(rateLimit?.primary);
	const secondary =
		asJsonObject(rateLimit?.secondary_window) ??
		asJsonObject(rateLimit?.secondary);
	const classified = [primary, secondary].map((window, index) => {
		const seconds =
			asFiniteNumber(window?.limit_window_seconds) ??
			(asFiniteNumber(window?.window_minutes) ?? 0) * 60;
		const label =
			seconds === 604_800
				? "Weekly"
				: seconds === 18_000
					? "Session"
					: index === 0
						? "Session"
						: "Weekly";
		return parseOpenAILimit(label, window);
	});
	return classified.filter((value): value is UsageLimit => value !== undefined);
}

export function parseResetCredits(
	body: JsonObject,
): readonly UsageResetCredit[] {
	return asJsonArray(body.credits)
		.map(asJsonObject)
		.filter(
			(credit): credit is JsonObject =>
				credit !== undefined &&
				(credit.status === undefined || credit.status === "available"),
		)
		.map((credit) => {
			const expiresAt = parseDateTime(credit.expires_at);
			return expiresAt ? { expiresAt } : {};
		})
		.sort(
			(left, right) =>
				(left.expiresAt?.valueOf() ?? Number.POSITIVE_INFINITY) -
				(right.expiresAt?.valueOf() ?? Number.POSITIVE_INFINITY),
		);
}

export class OpenAIProvider implements IProvider<OpenAIAuth, OpenAIRawUsage> {
	readonly id = "openai" as const;
	readonly displayName = "OpenAI";

	_getAuth(): OpenAIAuth {
		return getOpenAIAuth();
	}

	async _fetchUsage(auth: OpenAIAuth): Promise<OpenAIRawUsage> {
		const headers: Record<string, string> = {
			Authorization: `Bearer ${auth.accessToken}`,
			Accept: "application/json",
		};

		if (auth.accountId) headers["ChatGPT-Account-Id"] = auth.accountId;

		const [usage, credits] = await Promise.all([
			getJson(USAGE_URL, headers),
			getJson(CREDITS_URL, headers).catch(() => undefined),
		]);

		return credits ? { usage, credits } : { usage };
	}

	_parseUsage(rawUsage: OpenAIRawUsage): UsageSnapshot {
		const limits = parseOpenAIUsage(rawUsage.usage);
		if (limits.length === 0)
			throw new Error("OpenAI returned no usage windows");

		const resetCredits = rawUsage.credits
			? parseResetCredits(rawUsage.credits)
			: [];

		return resetCredits.length > 0
			? {
					providerId: this.id,
					displayName: this.displayName,
					limits,
					resetCredits,
				}
			: { providerId: this.id, displayName: this.displayName, limits };
	}

	async getUsage(): Promise<UsageSnapshot> {
		return this._parseUsage(await this._fetchUsage(await this._getAuth()));
	}
}
