export type JsonObject = Record<string, unknown>;

export function asJsonObject(value: unknown): JsonObject | undefined {
	return typeof value === "object" && value !== null && !Array.isArray(value)
		? (value as JsonObject)
		: undefined;
}

export function asJsonArray(value: unknown): readonly unknown[] {
	return Array.isArray(value) ? value : [];
}

export function asNonEmptyString(value: unknown): string | undefined {
	return typeof value === "string" && value.trim() !== "" ? value : undefined;
}

export function asFiniteNumber(value: unknown): number | undefined {
	const parsed =
		typeof value === "number"
			? value
			: typeof value === "string" && value.trim() !== ""
				? Number(value)
				: Number.NaN;
	return Number.isFinite(parsed) ? parsed : undefined;
}
