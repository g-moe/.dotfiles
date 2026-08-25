import type { UsageSnapshot } from "../domain/usage.js";

const DATE_FORMATTER = new Intl.DateTimeFormat("en-US", {
	month: "short",
	day: "numeric",
	hour: "numeric",
	minute: "2-digit",
	timeZoneName: "short",
});

const MINIMUM_BOX_WIDTH = 40;

const PERCENT_FORMATTER = new Intl.NumberFormat("en-US", {
	maximumFractionDigits: 1,
});

export function formatDateTime(date: Date): string {
	return DATE_FORMATTER.format(date);
}

function formatPercent(value: number): string {
	return `${PERCENT_FORMATTER.format(value)}%`;
}

export function formatUsageSnapshot(snapshot: UsageSnapshot): string {
	const lines = [snapshot.displayName];
	for (const [index, limit] of snapshot.limits.entries()) {
		if (index > 0) lines.push("");
		lines.push(
			`  ${limit.label}: ${formatPercent(Math.max(0, 100 - limit.usedPercent))} left`,
		);
		if (limit.resetsAt)
			lines.push(`  Resets: ${formatDateTime(limit.resetsAt)}`);
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
