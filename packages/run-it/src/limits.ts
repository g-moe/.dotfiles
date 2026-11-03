import { readFile } from "node:fs/promises";
import type { Options } from "./options.js";

/** Expand a Linux CPU list such as "0-3,8" into individual CPU IDs. */
export function parseCpuList(list: string): number[] {
	const cpus: number[] = [];

	for (const range of list.split(",")) {
		const isCpuOrRange = /^\d+(?:-\d+)?$/.test(range);
		if (!isCpuOrRange) {
			throw new Error(`Invalid CPU range: ${range}`);
		}

		const endpoints = range.split("-").map(Number);
		const firstCpu = endpoints[0];
		const lastCpu = endpoints[1] ?? firstCpu;
		if (firstCpu === undefined || lastCpu === undefined || lastCpu < firstCpu) {
			throw new Error(`Invalid CPU range: ${range}`);
		}

		for (let cpu = firstCpu; cpu <= lastCpu; cpu++) {
			cpus.push(cpu);
		}
	}

	return cpus;
}

async function selectCpus(requestedCount: number): Promise<string> {
	const status = await readFile("/proc/self/status", "utf8");
	const cpuListLine = status
		.split("\n")
		.find((line) => line.startsWith("Cpus_allowed_list:"));
	if (cpuListLine === undefined) {
		throw new Error("Could not read the available CPUs.");
	}

	const cpuList = cpuListLine.slice("Cpus_allowed_list:".length).trim();
	const availableCpus = parseCpuList(cpuList);
	if (requestedCount > availableCpus.length) {
		throw new Error(
			`Requested ${requestedCount} CPUs; only ${availableCpus.length} are available.`,
		);
	}

	const selectedCpus = availableCpus.slice(0, requestedCount);
	return selectedCpus.join(",");
}

/** Build the process wrappers before the shell command; limits cover its children. */
export async function commandArguments(options: Options): Promise<string[]> {
	const limitsRequested =
		options.cpu !== undefined || options.memoryGb !== undefined;
	if (limitsRequested && process.platform !== "linux") {
		throw new Error(
			"--cpu and --mem require Linux; omit them on other platforms.",
		);
	}

	const args: string[] = [];

	if (options.memoryGb !== undefined) {
		args.push(
			"systemd-run",
			"--user",
			"--scope",
			"--quiet",
			"-p",
			`MemoryMax=${options.memoryGb}G`,
			"-p",
			"MemorySwapMax=0",
		);
	}

	if (options.cpu !== undefined) {
		const selectedCpus = await selectCpus(options.cpu);
		args.push("taskset", "-c", selectedCpus);
	}

	const shell = process.env.SHELL || "/bin/sh";
	args.push(shell, "-c", options.command);

	return args;
}
