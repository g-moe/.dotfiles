function now() {
	return Date.now();
}

function toIso(
	input: string | undefined,
): { ok: true; iso: string; ms: number } | { ok: false; error: string } {
	const raw = input?.trim();
	const ms = raw ? Number(raw) : Date.now();

	if (!Number.isFinite(ms)) {
		return { ok: false, error: `Not a number: ${raw}` };
	}

	const date = new Date(ms);
	if (Number.isNaN(date.getTime())) {
		return { ok: false, error: `Invalid timestamp: ${raw}` };
	}

	return { ok: true, iso: date.toISOString(), ms };
}

export const Time = {
	toIso,
	now,
} as const;
