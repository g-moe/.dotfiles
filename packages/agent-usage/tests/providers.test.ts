import assert from "node:assert/strict";
import test from "node:test";
import type { IProvider } from "../src/domain/provider.ts";
import {
	ClaudeProvider,
	parseClaudeUsage,
} from "../src/providers/claude/index.ts";
import {
	CursorProvider,
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
			planUsage: { autoPercentUsed: 30 },
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
