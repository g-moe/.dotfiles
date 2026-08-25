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
	type UsageSnapshot,
} from "../../domain/usage.js";
import {
	readJsonFile,
	readMacKeychain,
	writeMacKeychain,
	writePrivateFile,
} from "../shared/files.js";

const CLIENT_ID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e";
const REFRESH_URL = "https://platform.claude.com/v1/oauth/token";
const SCOPES =
	"user:profile user:inference user:sessions:claude_code user:mcp_servers user:file_upload";
const USAGE_URL = "https://api.anthropic.com/api/oauth/usage";

interface ClaudeAuth {
	readonly authData: JsonObject;
	readonly credentialDocument: JsonObject;
	readonly saveCredentialDocument: (document: JsonObject) => void;
}

function getClaudeAuth(): ClaudeAuth {
	const keychain = readMacKeychain("Claude Code-credentials");
	if (keychain) {
		const document = asJsonObject(JSON.parse(keychain) as unknown);
		const auth = asJsonObject(document?.claudeAiOauth) ?? document;
		if (document && auth) {
			return {
				authData: auth,
				credentialDocument: document,
				saveCredentialDocument: (next) =>
					writeMacKeychain("Claude Code-credentials", JSON.stringify(next)),
			};
		}
	}
	const root = process.env.CLAUDE_CONFIG_DIR ?? `${homedir()}/.claude`;
	const path = `${root}/.credentials.json`;
	const document = asJsonObject(readJsonFile(path));
	const auth = asJsonObject(document?.claudeAiOauth) ?? document;
	if (!document || !auth)
		throw new Error("Claude Code credentials are invalid");
	return {
		authData: auth,
		credentialDocument: document,
		saveCredentialDocument: (next) =>
			writePrivateFile(path, `${JSON.stringify(next, null, 2)}\n`),
	};
}

async function refreshClaudeAuth(claudeAuth: ClaudeAuth): Promise<string> {
	const refreshToken = asNonEmptyString(claudeAuth.authData.refreshToken);
	if (!refreshToken)
		throw new Error("Claude session expired; run claude and sign in again");
	const response = await fetch(REFRESH_URL, {
		method: "POST",
		headers: { "Content-Type": "application/json" },
		body: JSON.stringify({
			grant_type: "refresh_token",
			refresh_token: refreshToken,
			client_id: CLIENT_ID,
			scope: SCOPES,
		}),
		signal: AbortSignal.timeout(10_000),
	});
	if (!response.ok)
		throw new Error("Claude session expired; run claude and sign in again");
	const body = asJsonObject((await response.json()) as unknown);
	const accessToken = asNonEmptyString(body?.access_token);
	if (!accessToken)
		throw new Error("Claude returned invalid refreshed credentials");
	const expiresInSeconds = asFiniteNumber(body?.expires_in);
	const nextAuth: JsonObject = {
		...claudeAuth.authData,
		accessToken,
		refreshToken: asNonEmptyString(body?.refresh_token) ?? refreshToken,
		expiresAt:
			Date.now() +
			(expiresInSeconds !== undefined && expiresInSeconds > 0
				? expiresInSeconds
				: 3_600) *
				1_000,
	};
	const nextDocument = claudeAuth.credentialDocument.claudeAiOauth
		? { ...claudeAuth.credentialDocument, claudeAiOauth: nextAuth }
		: nextAuth;
	claudeAuth.saveCredentialDocument(nextDocument);
	return accessToken;
}

async function fetchClaudeUsage(claudeAuth: ClaudeAuth): Promise<JsonObject> {
	let accessToken = asNonEmptyString(claudeAuth.authData.accessToken);
	const expiresAt = asFiniteNumber(claudeAuth.authData.expiresAt);
	if (
		!accessToken ||
		(expiresAt !== undefined && expiresAt <= Date.now() + 300_000)
	)
		accessToken = await refreshClaudeAuth(claudeAuth);
	const request = () =>
		fetch(USAGE_URL, {
			headers: {
				Authorization: `Bearer ${accessToken}`,
				"anthropic-beta": "oauth-2025-04-20",
				"User-Agent": "claude-code/2.1.69",
			},
			signal: AbortSignal.timeout(10_000),
		});
	let response = await request();
	if (response.status === 401 || response.status === 403) {
		accessToken = await refreshClaudeAuth(claudeAuth);
		response = await request();
	}
	if (!response.ok)
		throw new Error(`Request failed with HTTP ${response.status}`);
	const parsed = asJsonObject((await response.json()) as unknown);
	if (!parsed) throw new Error("Claude returned an invalid response");
	return parsed;
}

function parseLegacyLimit(
	label: string,
	value: unknown,
): UsageLimit | undefined {
	const window = asJsonObject(value);
	const usedPercent = parseUsedPercent(window?.utilization ?? window?.percent);
	if (usedPercent === undefined) return undefined;
	const resetsAt = parseDateTime(window?.resets_at);
	return resetsAt ? { label, usedPercent, resetsAt } : { label, usedPercent };
}

export function parseClaudeUsage(body: JsonObject): readonly UsageLimit[] {
	const legacyLimits = [
		parseLegacyLimit("Session", body.five_hour),
		parseLegacyLimit("Weekly", body.seven_day),
	].filter((value): value is UsageLimit => value !== undefined);
	if (legacyLimits.length > 0) return legacyLimits;
	return asJsonArray(body.limits)
		.map(asJsonObject)
		.flatMap((limit) => {
			if (!limit) return [];
			const kind = asNonEmptyString(limit.kind);
			const group = asNonEmptyString(limit.group);
			const label =
				kind === "session" || group === "session"
					? "Session"
					: kind === "weekly_all" || group === "weekly"
						? "Weekly"
						: undefined;
			if (!label) return [];
			const usedPercent = parseUsedPercent(limit.percent ?? limit.utilization);
			if (usedPercent === undefined) return [];
			const resetsAt = parseDateTime(limit.resets_at);
			return [
				resetsAt ? { label, usedPercent, resetsAt } : { label, usedPercent },
			];
		});
}

export class ClaudeProvider implements IProvider<ClaudeAuth, JsonObject> {
	readonly id = "claude" as const;
	readonly displayName = "Claude";

	_getAuth(): ClaudeAuth {
		return getClaudeAuth();
	}

	_fetchUsage(auth: ClaudeAuth): Promise<JsonObject> {
		return fetchClaudeUsage(auth);
	}

	_parseUsage(rawUsage: JsonObject): UsageSnapshot {
		const limits = parseClaudeUsage(rawUsage);
		if (limits.length === 0)
			throw new Error("Claude returned no usage windows");
		return { providerId: this.id, displayName: this.displayName, limits };
	}

	async getUsage(): Promise<UsageSnapshot> {
		return this._parseUsage(await this._fetchUsage(await this._getAuth()));
	}
}
