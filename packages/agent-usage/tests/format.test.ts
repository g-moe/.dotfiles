import assert from "node:assert/strict";
import test from "node:test";
import {
	formatProviderError,
	formatDateTime,
	formatUsageReport,
	formatUsageSnapshot,
} from "../src/cli/format.ts";

test("date-time formatter uses one stable English format in the local time zone", () => {
	assert.match(
		formatDateTime(new Date("2026-01-15T18:00:00Z")),
		/^Jan (15|16), \d{1,2}:\d{2} [AP]M \S+$/,
	);
});

test("snapshot formatter shows remaining percentages and reset credits", () => {
	const output = formatUsageSnapshot({
		providerId: "openai",
		displayName: "OpenAI",
		limits: [{ label: "Weekly", usedPercent: 10 }],
		resetCredits: [{ expiresAt: new Date("2026-09-01T00:00:00Z") }],
	});
	assert.match(output, /^OpenAI\n  Weekly: 90% left/);
	assert.match(output, /\n  Reset credits: 1\n    1\. Expires /);
});

test("snapshot formatter separates each limit group with one empty line", () => {
	const output = formatUsageSnapshot({
		providerId: "cursor",
		displayName: "Cursor",
		limits: [
			{ label: "Cursor Models", usedPercent: 66.7 },
			{ label: "Other Models", usedPercent: 100 },
		],
	});
	assert.equal(
		output,
		"Cursor\n  Cursor Models: 33.3% left\n\n  Other Models: 0% left",
	);
});

test("error formatter redacts API keys and bearer tokens", () => {
	const output = formatProviderError(
		"Claude",
		new Error("failed with sk-ant-secret and Bearer token-value"),
	);
	assert.equal(output.includes("sk-ant-secret"), false);
	assert.equal(output.includes("token-value"), false);
});

test("report formatter boxes providers with compact section spacing", () => {
	assert.equal(
		formatUsageReport(["OpenAI", "Claude"]),
		[
			"",
			"┌─ OpenAI ───────────────────────────────┐",
			"└────────────────────────────────────────┘",
			"",
			"┌─ Claude ───────────────────────────────┐",
			"└────────────────────────────────────────┘",
			"",
			"",
		].join("\n"),
	);
});
