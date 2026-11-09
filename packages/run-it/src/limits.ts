import { readdir, readFile } from "node:fs/promises";
import type { Options } from "./options.js";

/** Expand CPU ranges: "0-3,8" becomes [0, 1, 2, 3, 8]. */
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

type PickFreeCpusParams = {
	readonly availableCpus: readonly number[];
	readonly takenCpus: ReadonlySet<number>;
	readonly requestedCount: number;
};

/** Take the first CPUs that no other run-it is using; fail rather than share. */
export function pickFreeCpus(params: PickFreeCpusParams): number[] {
	const { availableCpus, takenCpus, requestedCount } = params;

	if (requestedCount > availableCpus.length) {
		throw new Error(
			`Requested ${requestedCount} CPUs; only ${availableCpus.length} are available.`,
		);
	}

	const freeCpus = availableCpus.filter((cpu) => !takenCpus.has(cpu));
	if (requestedCount > freeCpus.length) {
		throw new Error(
			`Requested ${requestedCount} CPUs; only ${freeCpus.length} are free. Other run-it commands are using CPUs ${[...takenCpus].join(",")}.`,
		);
	}

	return freeCpus.slice(0, requestedCount);
}

/** Read a process's allowed CPUs; undefined when the process has exited. */
async function allowedCpus(pid: string): Promise<number[] | undefined> {
	try {
		const status = await readFile(`/proc/${pid}/status`, "utf8");
		const cpuListLine = status
			.split("\n")
			.find((line) => line.startsWith("Cpus_allowed_list:"));
		if (cpuListLine === undefined) {
			return undefined;
		}

		return parseCpuList(cpuListLine.slice("Cpus_allowed_list:".length).trim());
	} catch {
		return undefined;
	}
}

/** List the direct child PIDs of a process; empty when it has exited. */
async function childPids(pid: string): Promise<string[]> {
	try {
		const children = await readFile(
			`/proc/${pid}/task/${pid}/children`,
			"utf8",
		);
		return children.split(" ").filter(Boolean);
	} catch {
		return [];
	}
}

/** List PIDs of other run-it processes started from the same executable path. */
async function otherRunItPids(): Promise<string[]> {
	const executablePath = process.argv[1];
	const ownPid = String(process.pid);
	const pids = (await readdir("/proc")).filter((name) => /^\d+$/.test(name));
	const matches: string[] = [];

	for (const pid of pids) {
		if (pid === ownPid) {
			continue;
		}

		try {
			const argv = (await readFile(`/proc/${pid}/cmdline`, "utf8")).split("\0");
			if (argv[1] === executablePath) {
				matches.push(pid);
			}
		} catch {
			// The process exited while scanning.
		}
	}

	return matches;
}

/** Collect CPUs pinned by other run-it commands, read from their running child's affinity. */
async function cpusUsedByOtherRuns(
	availableCpus: readonly number[],
): Promise<Set<number>> {
	const takenCpus = new Set<number>();

	for (const pid of await otherRunItPids()) {
		for (const childPid of await childPids(pid)) {
			const cpus = await allowedCpus(childPid);
			const isPinned = cpus !== undefined && cpus.length < availableCpus.length;
			if (isPinned) {
				cpus.forEach((cpu) => takenCpus.add(cpu));
			}
		}
	}

	return takenCpus;
}

async function selectCpus(requestedCount: number): Promise<string> {
	const availableCpus = await allowedCpus("self");
	if (availableCpus === undefined) {
		throw new Error("Could not read the available CPUs.");
	}

	const takenCpus = await cpusUsedByOtherRuns(availableCpus);
	return pickFreeCpus({ availableCpus, takenCpus, requestedCount }).join(",");
}

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
