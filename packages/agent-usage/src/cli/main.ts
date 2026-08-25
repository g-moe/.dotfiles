#!/usr/bin/env node
import {
	formatProviderError,
	formatUsageReport,
	formatUsageSnapshot,
} from "./format.js";
import { ClaudeProvider } from "../providers/claude/index.js";
import { CursorProvider } from "../providers/cursor/index.js";
import { OpenAIProvider } from "../providers/openai/index.js";

if (process.argv.length > 2) {
	console.error("agent-usage does not accept arguments");
	process.exitCode = 2;
} else {
	const providers = [
		new OpenAIProvider(),
		new ClaudeProvider(),
		new CursorProvider(),
	] as const;
	const results = await Promise.allSettled(
		providers.map((provider) => provider.getUsage()),
	);
	const sections = results.map((result, index) => {
		if (result.status === "fulfilled") return formatUsageSnapshot(result.value);
		const provider = providers[index];
		return formatProviderError(
			provider?.displayName ?? "Unknown provider",
			result.reason,
		);
	});
	process.stdout.write(formatUsageReport(sections));
	if (results.every((result) => result.status === "rejected"))
		process.exitCode = 1;
}
