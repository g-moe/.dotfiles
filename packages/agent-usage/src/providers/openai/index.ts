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
	createResetCredit,
	createUsageLimit,
	parseDateTime,
	parseUsedPercent,
	sortResetCredits,
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

function getOpenAILimitLabel(windowSeconds: number, index: number): string {
	if (windowSeconds === 604_800) return "Weekly";
	if (windowSeconds === 18_000) return "Session";

	// Unknown durations fall back to position: the primary window is the session
	return index === 0 ? "Session" : "Weekly";
}

function parseOpenAIResetTime(value: JsonObject | undefined): Date | undefined {
	const absoluteReset = parseDateTime(value?.reset_at);
	if (absoluteReset) return absoluteReset;

	const relativeSeconds = asFiniteNumber(value?.reset_after_seconds);
	if (relativeSeconds === undefined) return undefined;

	return new Date(Date.now() + relativeSeconds * 1_000);
}

function parseOpenAILimit(
	label: string,
	value: JsonObject | undefined,
): UsageLimit | undefined {
	const usedPercent = parseUsedPercent(value?.used_percent);
	if (usedPercent === undefined) return undefined;
	return createUsageLimit(label, usedPercent, parseOpenAIResetTime(value));
}

export function parseOpenAIUsage(body: JsonObject): readonly UsageLimit[] {
	const rateLimit = asJsonObject(body.rate_limit);
	const primary =
		asJsonObject(rateLimit?.primary_window) ?? asJsonObject(rateLimit?.primary);
	const secondary =
		asJsonObject(rateLimit?.secondary_window) ??
		asJsonObject(rateLimit?.secondary);
	const classified = [primary, secondary].map((window, index) => {
		const windowSeconds =
			asFiniteNumber(window?.limit_window_seconds) ??
			(asFiniteNumber(window?.window_minutes) ?? 0) * 60;
		return parseOpenAILimit(getOpenAILimitLabel(windowSeconds, index), window);
	});
	return classified.filter((value): value is UsageLimit => value !== undefined);
}

export function parseResetCredits(
	body: JsonObject,
): readonly UsageResetCredit[] {
	const credits = asJsonArray(body.credits)
		.map(asJsonObject)
		.filter(
			(credit): credit is JsonObject =>
				credit !== undefined &&
				(credit.status === undefined || credit.status === "available"),
		)
		.map((credit) => createResetCredit(parseDateTime(credit.expires_at)));
	return sortResetCredits(credits);
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

		const snapshot = {
			providerId: this.id,
			displayName: this.displayName,
			limits,
		};

		// Omit reset credits only when the credits request failed, so failure never reads as zero
		return rawUsage.credits
			? { ...snapshot, resetCredits: parseResetCredits(rawUsage.credits) }
			: snapshot;
	}

	async getUsage(): Promise<UsageSnapshot> {
		return this._parseUsage(await this._fetchUsage(await this._getAuth()));
	}
}
