import type { UsageSnapshot, UsageSpend } from "../domain/usage.js";

const DATE_FORMATTER = new Intl.DateTimeFormat("en-US", {
	month: "short",
	day: "numeric",
	hour: "numeric",
	minute: "2-digit",
	timeZoneName: "short",
});

const MINIMUM_BOX_WIDTH = 40;

const USD_FORMATTER = new Intl.NumberFormat("en-US", {
	style: "currency",
	currency: "USD",
});

const PERCENT_FORMATTER = new Intl.NumberFormat("en-US", {
	maximumFractionDigits: 1,
});

export function formatDateTime(date: Date): string {
	return DATE_FORMATTER.format(date);
}

function formatPercent(value: number): string {
	return `${PERCENT_FORMATTER.format(value)}%`;
}

function formatUsd(value: number): string {
	return USD_FORMATTER.format(value);
}

/**
 * Format each credential as one group with its cap and spend, followed by a
 * monthly total when there is more than one credential.
 */
function formatSpend(spend: readonly UsageSpend[]): readonly string[] {
	const lines: string[] = [];

	for (const [index, entry] of spend.entries()) {
		if (index > 0) lines.push("");
		lines.push(`  ${entry.label}`);
		if (entry.capUsedPercent !== undefined) {
			const percentLeft = Math.max(0, 100 - entry.capUsedPercent);
			lines.push(`    Cap: ${formatPercent(percentLeft)} left`);
		}
		lines.push(
			`    Spend: ${formatUsd(entry.monthUsd)} month · ${formatUsd(entry.weekUsd)} week · ${formatUsd(entry.todayUsd)} today`,
		);
	}
	if (spend.length < 2) return lines;

	const monthTotal = spend.reduce((total, { monthUsd }) => total + monthUsd, 0);
	return [...lines, "", `  Total: ${formatUsd(monthTotal)} month`];
}

export function formatUsageSnapshot(snapshot: UsageSnapshot): string {
	const lines = [snapshot.displayName];
	for (const [index, limit] of snapshot.limits.entries()) {
		if (index > 0) lines.push("");
		const percentLeft = Math.max(0, 100 - limit.usedPercent);
		lines.push(`  ${limit.label}: ${formatPercent(percentLeft)} left`);
		if (limit.resetsAt)
			lines.push(`  Resets: ${formatDateTime(limit.resetsAt)}`);
	}
	if (snapshot.spend) {
		if (snapshot.limits.length > 0) lines.push("");
		lines.push(...formatSpend(snapshot.spend));
	}
	if (snapshot.resetCredits) {
		lines.push(`  Reset credits: ${snapshot.resetCredits.length}`);
		snapshot.resetCredits.forEach((credit, index) => {
			if (credit.expiresAt)
				lines.push(
					`    ${index + 1}. Expires ${formatDateTime(credit.expiresAt)}`,
				);
		});
	}
	return lines.join("\n");
}

export function formatProviderError(
	displayName: string,
	error: unknown,
): string {
	const rawMessage =
		error instanceof Error ? error.message : "usage is unavailable";
	const message = rawMessage
		.replace(/sk-[A-Za-z0-9_-]+/g, "[redacted]")
		.replace(/Bearer\s+\S+/gi, "Bearer [redacted]");
	return `${displayName}\n  Unavailable: ${message}`;
}

export function formatUsageReport(sections: readonly string[]): string {
	return `\n${sections.map(formatBox).join("\n\n")}\n\n`;
}

function formatBox(section: string): string {
	const [title = "Usage", ...body] = section.split("\n");
	const innerWidth = Math.max(
		MINIMUM_BOX_WIDTH,
		title.length + 3,
		...body.map((line) => line.length),
	);
	const top = `┌─ ${title} ${"─".repeat(innerWidth - title.length - 3)}┐`;
	const rows = body.map((line) => `│${line.padEnd(innerWidth)}│`);
	return [top, ...rows, `└${"─".repeat(innerWidth)}┘`].join("\n");
}
