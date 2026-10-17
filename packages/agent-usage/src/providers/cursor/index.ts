import { existsSync } from "node:fs";
import { homedir } from "node:os";
import {
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
import { readJsonFile, readMacKeychain } from "../shared/files.js";
import { postJson } from "../shared/http.js";

const RESETS_URL =
	"https://api2.cursor.sh/aiserver.v1.DashboardService/ListSandBankedResets";
const USAGE_URL =
	"https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage";

interface CursorAuth {
	readonly accessToken: string;
}

interface CursorRawUsage {
	readonly usage: JsonObject;
	readonly resets?: JsonObject;
}

export function getCursorAuthFilePath(
	platform: NodeJS.Platform = process.platform,
	homeDirectory: string = homedir(),
	configDirectory: string | undefined = process.env.XDG_CONFIG_HOME,
): string {
	if (platform === "darwin") return `${homeDirectory}/.cursor/auth.json`;
	configDirectory ??= `${homeDirectory}/.config`;
	return `${configDirectory}/cursor/auth.json`;
}

function getCursorAuth(): CursorAuth {
	const environmentToken = asNonEmptyString(process.env.CURSOR_AUTH_TOKEN);
	if (environmentToken) return { accessToken: environmentToken };

	const usesFileStore =
		process.platform !== "darwin" ||
		process.env.AGENT_CLI_CREDENTIAL_STORE === "file";
	const authFilePath = getCursorAuthFilePath();
	if (usesFileStore && existsSync(authFilePath)) {
		const authDocument = asJsonObject(readJsonFile(authFilePath));
		const accessToken = asNonEmptyString(authDocument?.accessToken);
		if (accessToken) return { accessToken };
	}

	if (!usesFileStore) {
		const keychainToken = readMacKeychain("cursor-access-token");
		if (keychainToken) return { accessToken: keychainToken };
	}

	throw new Error("Cursor CLI is not signed in; run cursor-agent login");
}

function parseCursorLimit(
	label: string,
	value: unknown,
	resetsAt: Date | undefined,
): UsageLimit | undefined {
	const usedPercent = parseUsedPercent(value);
	if (usedPercent === undefined) return undefined;
	return createUsageLimit(label, usedPercent, resetsAt);
}

export function parseCursorUsage(body: JsonObject): readonly UsageLimit[] {
	if (body.enabled === false) return [];
	const plan = asJsonObject(body.planUsage);
	const resetsAt = parseDateTime(body.billingCycleEnd);
	return [
		parseCursorLimit("Cursor Models", plan?.autoPercentUsed, resetsAt),
		parseCursorLimit("Other Models", plan?.apiPercentUsed, resetsAt),
	].filter((value): value is UsageLimit => value !== undefined);
}

/**
 * Map Cursor banked resets into reset credits.
 * The response lists only unused resets, so every entry counts.
 *
 * @example
 * parseCursorResetCredits({ resets: [{ id: "1", expiresAt: "2026-11-01T00:00:00Z" }] }).length; // 1
 */
export function parseCursorResetCredits(
	body: JsonObject,
): readonly UsageResetCredit[] {
	const credits = asJsonArray(body.resets)
		.map(asJsonObject)
		.filter((reset): reset is JsonObject => reset !== undefined)
		.map((reset) => createResetCredit(parseDateTime(reset.expiresAt)));
	return sortResetCredits(credits);
}

export class CursorProvider implements IProvider<CursorAuth, CursorRawUsage> {
	readonly id = "cursor" as const;
	readonly displayName = "Cursor";

	_getAuth(): CursorAuth {
		return getCursorAuth();
	}

	async _fetchUsage(auth: CursorAuth): Promise<CursorRawUsage> {
		const headers = {
			Authorization: `Bearer ${auth.accessToken}`,
			"Content-Type": "application/json",
			"Connect-Protocol-Version": "1",
		};

		const [usage, resets] = await Promise.all([
			postJson(USAGE_URL, headers),
			postJson(RESETS_URL, headers).catch(() => undefined),
		]);

		return resets ? { usage, resets } : { usage };
	}

	_parseUsage(rawUsage: CursorRawUsage): UsageSnapshot {
		const limits = parseCursorUsage(rawUsage.usage);
		if (limits.length === 0) throw new Error("Cursor returned no plan usage");

		const snapshot = {
			providerId: this.id,
			displayName: this.displayName,
			limits,
		};

		// Omit reset credits only when the resets request failed, so failure never reads as zero
		return rawUsage.resets
			? { ...snapshot, resetCredits: parseCursorResetCredits(rawUsage.resets) }
			: snapshot;
	}

	async getUsage(): Promise<UsageSnapshot> {
		return this._parseUsage(await this._fetchUsage(await this._getAuth()));
	}
}
