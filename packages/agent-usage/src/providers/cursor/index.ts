import { existsSync } from "node:fs";
import { homedir } from "node:os";
import {
	asJsonObject,
	asNonEmptyString,
	type JsonObject,
} from "../../domain/json.js";
import type { IProvider } from "../../domain/provider.js";
import {
	parseDateTime,
	parseUsedPercent,
	type UsageLimit,
	type UsageSnapshot,
} from "../../domain/usage.js";
import { readJsonFile, readMacKeychain } from "../shared/files.js";
import { postJson } from "../shared/http.js";

const USAGE_URL =
	"https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage";

interface CursorAuth {
	readonly accessToken: string;
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

	const keychainToken = usesFileStore
		? undefined
		: readMacKeychain("cursor-access-token");
	if (keychainToken) return { accessToken: keychainToken };

	throw new Error("Cursor CLI is not signed in; run cursor-agent login");
}

function parseCursorLimit(
	label: string,
	value: unknown,
	resetsAt: Date | undefined,
): UsageLimit | undefined {
	const usedPercent = parseUsedPercent(value);
	if (usedPercent === undefined) return undefined;
	return resetsAt ? { label, usedPercent, resetsAt } : { label, usedPercent };
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

export class CursorProvider implements IProvider<CursorAuth, JsonObject> {
	readonly id = "cursor" as const;
	readonly displayName = "Cursor";

	_getAuth(): CursorAuth {
		return getCursorAuth();
	}

	_fetchUsage(auth: CursorAuth): Promise<JsonObject> {
		return postJson(USAGE_URL, {
			Authorization: `Bearer ${auth.accessToken}`,
			"Content-Type": "application/json",
			"Connect-Protocol-Version": "1",
		});
	}

	_parseUsage(rawUsage: JsonObject): UsageSnapshot {
		const limits = parseCursorUsage(rawUsage);
		if (limits.length === 0) throw new Error("Cursor returned no plan usage");
		return { providerId: this.id, displayName: this.displayName, limits };
	}

	async getUsage(): Promise<UsageSnapshot> {
		return this._parseUsage(await this._fetchUsage(await this._getAuth()));
	}
}
