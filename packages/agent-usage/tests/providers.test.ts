import assert from "node:assert/strict";
import test from "node:test";
import type { IProvider } from "../src/domain/provider.ts";
import {
	ClaudeProvider,
	parseClaudeResetCredits,
	parseClaudeUsage,
} from "../src/providers/claude/index.ts";
import {
	CursorProvider,
	getCursorAuthFilePath,
	parseCursorResetCredits,
	parseCursorUsage,
} from "../src/providers/cursor/index.ts";
import {
	OpenAIProvider,
	parseOpenAIUsage,
	parseResetCredits,
} from "../src/providers/openai/index.ts";

test("all providers implement the same public contract", () => {
	const providers: readonly IProvider[] = [
		new OpenAIProvider(),
		new ClaudeProvider(),
		new CursorProvider(),
	];
	for (const provider of providers) {
		assert.equal(typeof provider.id, "string");
		assert.equal(typeof provider.displayName, "string");
		assert.equal(typeof provider._getAuth, "function");
		assert.equal(typeof provider._fetchUsage, "function");
		assert.equal(typeof provider._parseUsage, "function");
		assert.equal(typeof provider.getUsage, "function");
	}
});

test("all providers parse raw usage into snapshots with matching identities", () => {
	const snapshots = [
		new OpenAIProvider()._parseUsage({
			usage: { rate_limit: { primary: { used_percent: 10 } } },
		}),
		new ClaudeProvider()._parseUsage({ five_hour: { utilization: 20 } }),
		new CursorProvider()._parseUsage({
			usage: { planUsage: { autoPercentUsed: 30 } },
		}),
	];
	assert.deepEqual(
		snapshots.map(({ providerId, displayName }) => ({
			providerId,
			displayName,
		})),
		[
			{ providerId: "openai", displayName: "OpenAI" },
			{ providerId: "claude", displayName: "Claude" },
			{ providerId: "cursor", displayName: "Cursor" },
		],
	);
});

test("OpenAI classifies session and weekly limits by duration", () => {
	const limits = parseOpenAIUsage({
		rate_limit: {
			primary_window: {
				used_percent: 12,
				limit_window_seconds: 18_000,
				reset_at: 1_800_000_000,
			},
			secondary_window: {
				used_percent: 34,
				limit_window_seconds: 604_800,
				reset_at: 1_800_600_000,
			},
		},
	});
	assert.deepEqual(
		limits.map(({ label, usedPercent }) => ({ label, usedPercent })),
		[
			{ label: "Session", usedPercent: 12 },
			{ label: "Weekly", usedPercent: 34 },
		],
	);
});

test("OpenAI uses relative reset times when absolute times are absent", () => {
	const beforeParse = Date.now();
	const [limit] = parseOpenAIUsage({
		rate_limit: {
			primary_window: {
				used_percent: 12,
				reset_after_seconds: 60,
			},
		},
	});
	const afterParse = Date.now();
	assert.ok(limit?.resetsAt);
	assert.ok(limit.resetsAt.valueOf() >= beforeParse + 60_000);
	assert.ok(limit.resetsAt.valueOf() <= afterParse + 60_000);
});

test("OpenAI includes only available reset credits in expiry order", () => {
	const credits = parseResetCredits({
		credits: [
			{ status: "available", expires_at: "2026-09-02T00:00:00Z" },
			{ status: "redeemed", expires_at: "2026-08-01T00:00:00Z" },
			{ status: "available", expires_at: "2026-09-01T00:00:00Z" },
			{ status: "available" },
		],
	});
	assert.deepEqual(
		credits.map(({ expiresAt }) => expiresAt?.toISOString()),
		["2026-09-01T00:00:00.000Z", "2026-09-02T00:00:00.000Z", undefined],
	);
});

test("Claude parses legacy session and weekly limits", () => {
	const limits = parseClaudeUsage({
		five_hour: { utilization: 25, resets_at: "2026-08-25T20:00:00Z" },
		seven_day: { utilization: 40, resets_at: "2026-08-30T20:00:00Z" },
	});
	assert.deepEqual(
		limits.map(({ label, usedPercent }) => ({ label, usedPercent })),
		[
			{ label: "Session", usedPercent: 25 },
			{ label: "Weekly", usedPercent: 40 },
		],
	);
});

test("Claude parses the limits-array response shape", () => {
	const limits = parseClaudeUsage({
		limits: [
			{ kind: "session", percent: 15 },
			{ group: "weekly", utilization: 35 },
			{ kind: "unsupported", percent: 50 },
		],
	});
	assert.deepEqual(
		limits.map(({ label, usedPercent }) => ({ label, usedPercent })),
		[
			{ label: "Session", usedPercent: 15 },
			{ label: "Weekly", usedPercent: 35 },
		],
	);
});

test("Claude expands reset grants into credits in expiry order", () => {
	const credits = parseClaudeResetCredits({
		cedar_ember: {
			grants: [
				{ resets_left: 1, ends_at: "2026-10-30T00:00:00Z" },
				{ resets_left: 0, ends_at: "2026-10-01T00:00:00Z" },
				{ resets_left: 2, ends_at: "2026-10-22T00:00:00Z" },
				{ ends_at: "2026-10-02T00:00:00Z" },
			],
		},
	});
	assert.deepEqual(
		credits.map(({ expiresAt }) => expiresAt?.toISOString()),
		[
			"2026-10-22T00:00:00.000Z",
			"2026-10-22T00:00:00.000Z",
			"2026-10-30T00:00:00.000Z",
		],
	);
});

test("Claude returns no reset credits when the account is ineligible", () => {
	assert.deepEqual(
		parseClaudeResetCredits({
			cedar_ember: { eligible: false, grants: [] },
		}),
		[],
	);
	assert.deepEqual(parseClaudeResetCredits({ cedar_ember: null }), []);
});

test("Cursor maps banked resets into credits in expiry order", () => {
	const credits = parseCursorResetCredits({
		resets: [
			{ id: "2", expiresAt: "2026-11-02T00:00:00Z" },
			{ id: "3" },
			{ id: "1", expiresAt: "2026-11-01T00:00:00Z" },
		],
	});
	assert.deepEqual(
		credits.map(({ expiresAt }) => expiresAt?.toISOString()),
		["2026-11-01T00:00:00.000Z", "2026-11-02T00:00:00.000Z", undefined],
	);
	assert.deepEqual(parseCursorResetCredits({}), []);
});

test("Cursor attaches banked resets to the snapshot", () => {
	const snapshot = new CursorProvider()._parseUsage({
		usage: { planUsage: { autoPercentUsed: 30 } },
		resets: { resets: [{ id: "1", expiresAt: "2026-11-01T00:00:00Z" }] },
	});
	assert.equal(snapshot.resetCredits?.length, 1);
});

test("providers report zero reset credits when the reset data has none", () => {
	const snapshots = [
		new OpenAIProvider()._parseUsage({
			usage: { rate_limit: { primary: { used_percent: 10 } } },
			credits: { credits: [] },
		}),
		new ClaudeProvider()._parseUsage({
			five_hour: { utilization: 20 },
			cedar_ember: { eligible: false, grants: [] },
		}),
		new CursorProvider()._parseUsage({
			usage: { planUsage: { autoPercentUsed: 30 } },
			resets: {},
		}),
	];
	assert.deepEqual(
		snapshots.map(({ resetCredits }) => resetCredits),
		[[], [], []],
	);
});

test("providers omit reset credits when the reset data is missing", () => {
	const snapshots = [
		new OpenAIProvider()._parseUsage({
			usage: { rate_limit: { primary: { used_percent: 10 } } },
		}),
		new ClaudeProvider()._parseUsage({ five_hour: { utilization: 20 } }),
		new CursorProvider()._parseUsage({
			usage: { planUsage: { autoPercentUsed: 30 } },
		}),
	];
	assert.deepEqual(
		snapshots.map(({ resetCredits }) => resetCredits),
		[undefined, undefined, undefined],
	);
});

test("Cursor maps model percentages and omits the total percentage", () => {
	const limits = parseCursorUsage({
		enabled: true,
		billingCycleEnd: 1_800_000_000_000,
		planUsage: {
			totalPercentUsed: 20,
			autoPercentUsed: 12.5,
			apiPercentUsed: 7.5,
		},
	});
	assert.deepEqual(
		limits.map(({ label, usedPercent }) => ({ label, usedPercent })),
		[
			{ label: "Cursor Models", usedPercent: 12.5 },
			{ label: "Other Models", usedPercent: 7.5 },
		],
	);
});

test("Cursor returns no limits when plan usage is disabled", () => {
	assert.deepEqual(parseCursorUsage({ enabled: false }), []);
});

test("Cursor uses the Cursor CLI authentication paths", () => {
	assert.equal(
		getCursorAuthFilePath("linux", "/home/user"),
		"/home/user/.config/cursor/auth.json",
	);
	assert.equal(
		getCursorAuthFilePath("linux", "/home/user", "/config"),
		"/config/cursor/auth.json",
	);
	assert.equal(
		getCursorAuthFilePath("darwin", "/Users/user"),
		"/Users/user/.cursor/auth.json",
	);
});
