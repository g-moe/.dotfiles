import { asFiniteNumber } from "./json.js";

export type UsageProviderId = "openai" | "claude" | "cursor" | "openrouter";

export interface UsageLimit {
	readonly label: string;
	readonly usedPercent: number;
	readonly resetsAt?: Date;
}

export interface UsageResetCredit {
	readonly expiresAt?: Date;
}

/**
 * Dollars spent through one credential in the current UTC day, week, and month.
 * `capUsedPercent` is present only when the credential has a spending cap.
 */
export interface UsageSpend {
	readonly label: string;
	readonly capUsedPercent?: number;
	readonly todayUsd: number;
	readonly weekUsd: number;
	readonly monthUsd: number;
}

export interface UsageSnapshot {
	readonly providerId: UsageProviderId;
	readonly displayName: string;
	readonly limits: readonly UsageLimit[];
	readonly resetCredits?: readonly UsageResetCredit[];
	readonly spend?: readonly UsageSpend[];
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
	const parsed = asFiniteNumber(value);
	if (parsed === undefined || parsed < 0) return undefined;
	return Math.min(100, parsed);
}

/**
 * Build a usage limit, leaving `resetsAt` out when the reset time is unknown.
 */
export function createUsageLimit(
	label: string,
	usedPercent: number,
	resetsAt: Date | undefined,
): UsageLimit {
	return resetsAt ? { label, usedPercent, resetsAt } : { label, usedPercent };
}

/**
 * Build a reset credit, leaving `expiresAt` out when the expiry is unknown.
 */
export function createResetCredit(
	expiresAt: Date | undefined,
): UsageResetCredit {
	return expiresAt ? { expiresAt } : {};
}

/**
 * Order reset credits by expiry, soonest first; credits without an expiry go last.
 */
export function sortResetCredits(
	credits: readonly UsageResetCredit[],
): readonly UsageResetCredit[] {
	return [...credits].sort(
		(left, right) =>
			(left.expiresAt?.valueOf() ?? Number.POSITIVE_INFINITY) -
			(right.expiresAt?.valueOf() ?? Number.POSITIVE_INFINITY),
	);
}
