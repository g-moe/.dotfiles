export type UsageProviderId = "openai" | "claude" | "cursor";

export interface UsageLimit {
	readonly label: string;
	readonly usedPercent: number;
	readonly resetsAt?: Date;
}

export interface UsageResetCredit {
	readonly expiresAt?: Date;
}

export interface UsageSnapshot {
	readonly providerId: UsageProviderId;
	readonly displayName: string;
	readonly limits: readonly UsageLimit[];
	readonly resetCredits?: readonly UsageResetCredit[];
}

export function parseDateTime(value: unknown): Date | undefined {
	if (typeof value === "number" && Number.isFinite(value)) {
		const milliseconds = value > 10_000_000_000 ? value : value * 1_000;
		const date = new Date(milliseconds);
		return Number.isNaN(date.valueOf()) ? undefined : date;
	}
	if (typeof value !== "string" || value.trim() === "") return undefined;
	const numeric = Number(value);
	if (Number.isFinite(numeric)) return parseDateTime(numeric);
	const date = new Date(value);
	return Number.isNaN(date.valueOf()) ? undefined : date;
}

export function parseUsedPercent(value: unknown): number | undefined {
	const parsed =
		typeof value === "number"
			? value
			: typeof value === "string" && value.trim() !== ""
				? Number(value)
				: Number.NaN;
	if (!Number.isFinite(parsed) || parsed < 0) return undefined;
	return Math.min(100, parsed);
}
