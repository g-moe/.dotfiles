import { parseArgs } from "node:util";

export const USAGE = 'Usage: run-it "cmd" --runs=10 [--cpu=2] [--mem=8]';

export type Options = {
	readonly command: string;
	readonly runs: number;
	readonly cpu: number | undefined;
	readonly memoryGb: number | undefined;
};

function positiveInteger(
	name: string,
	value: string | undefined,
): number | undefined {
	if (value === undefined) {
		return undefined;
	}

	const number = Number(value);
	const containsOnlyDigits = /^[0-9]+$/.test(value);
	const isPositiveInteger = Number.isSafeInteger(number) && number > 0;
	if (!containsOnlyDigits || !isPositiveInteger) {
		throw new Error(`${name} must be a positive integer.`);
	}

	return number;
}

export function parseOptions(args: readonly string[]): Options {
	const { values, positionals } = parseArgs({
		args: [...args],
		allowPositionals: true,
		options: {
			runs: { type: "string" },
			cpu: { type: "string" },
			mem: { type: "string" },
		},
	});

	const command = positionals[0];
	if (positionals.length !== 1 || !command?.trim()) {
		throw new Error("Provide exactly one quoted command.");
	}

	const runs = positiveInteger("--runs", values.runs);
	if (runs === undefined) {
		throw new Error("--runs is required.");
	}

	return {
		command,
		runs,
		cpu: positiveInteger("--cpu", values.cpu),
		memoryGb: positiveInteger("--mem", values.mem),
	};
}
