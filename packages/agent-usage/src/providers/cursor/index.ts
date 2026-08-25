import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { asJsonObject, type JsonObject } from "../../domain/json.js";
import type { IProvider } from "../../domain/provider.js";
import {
	parseDateTime,
	parseUsedPercent,
	type UsageLimit,
	type UsageSnapshot,
} from "../../domain/usage.js";
import { readMacKeychain } from "../shared/files.js";
import { postJson } from "../shared/http.js";

const USAGE_URL =
	"https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage";

interface CursorAuth {
	readonly accessToken: string;
}

function getCursorDatabasePaths(): readonly string[] {
	if (process.platform === "darwin") {
		return [
			`${homedir()}/Library/Application Support/Cursor/User/globalStorage/state.vscdb`,
		];
	}
	const config = process.env.XDG_CONFIG_HOME ?? `${homedir()}/.config`;
	return [
		`${config}/Cursor/User/globalStorage/state.vscdb`,
		`${config}/cursor/User/globalStorage/state.vscdb`,
	];
}

function getSqliteValue(path: string, key: string): string | undefined {
	try {
		const value = execFileSync(
			"sqlite3",
			[path, `SELECT value FROM ItemTable WHERE key='${key}' LIMIT 1;`],
			{
				encoding: "utf8",
				stdio: ["ignore", "pipe", "ignore"],
			},
		).trim();
		return value || undefined;
	} catch {
		return undefined;
	}
}

function getCursorAuth(): CursorAuth {
	const database = getCursorDatabasePaths().find(existsSync);
	const token = database
		? getSqliteValue(database, "cursorAuth/accessToken")
		: undefined;
	const fallback = readMacKeychain("cursor-access-token");
	if (token) return { accessToken: token };
	if (fallback) return { accessToken: fallback };
	throw new Error("Cursor is not signed in or sqlite3 is unavailable");
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
