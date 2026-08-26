import { PATHS } from "../paths";
import type { CreateInstallModule } from "../types";
import { readJsonc } from "../utils";

type JsonRecord = Record<string, unknown>;

function isRecord(value: unknown): value is JsonRecord {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

function assertColorMap(value: unknown, label: string): void {
	if (!isRecord(value) || Object.keys(value).length === 0) {
		throw new Error(`T3 Code ${label} must contain color roles.`);
	}

	for (const [role, color] of Object.entries(value)) {
		if (
			typeof color !== "string" ||
			!/^#[\da-f]{6}(?:[\da-f]{2})?$/iu.test(color)
		) {
			throw new Error(`T3 Code ${label}.${role} must be a hex color.`);
		}
	}
}

function assertT3CodeTheme(value: unknown): void {
	if (!isRecord(value)) {
		throw new Error("T3 Code theme must be a JSON object.");
	}
	if (value.version !== 1) {
		throw new Error("T3 Code theme must use version 1.");
	}
	if (typeof value.id !== "string" || typeof value.name !== "string") {
		throw new Error("T3 Code theme must have an id and name.");
	}
	if (value.appearance !== "dark" && value.appearance !== "light") {
		throw new Error('T3 Code theme appearance must be "dark" or "light".');
	}

	assertColorMap(value.colors, "colors");
	if (!isRecord(value.variants) || !value.variants.light) {
		throw new Error("T3 Code theme must contain a variants.light palette.");
	}
	assertColorMap(value.variants.light, "variants.light");
}

export const t3CodeApp: CreateInstallModule = {
	appName: "t3-code",
	async create() {
		const theme = await readJsonc<unknown>(PATHS.t3code.theme);
		assertT3CodeTheme(theme);
		return [PATHS.t3code.theme];
	},
	async install() {
		// T3 Code imports this single file from Settings → Themes → Import theme.
		return [PATHS.t3code.theme];
	},
};
