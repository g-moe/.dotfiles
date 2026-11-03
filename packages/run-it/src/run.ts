import { createReadStream } from "node:fs";
import { createInterface } from "node:readline";
import { spawn } from "node:child_process";
import { mkdtemp, open } from "node:fs/promises";
import { constants, tmpdir } from "node:os";
import { join } from "node:path";
import type { Options } from "./options.js";
import { commandArguments } from "./limits.js";

type ExecuteOptions = {
	readonly args: readonly string[];
	readonly logFile: string;
};

async function printFailure(logFile: string): Promise<void> {
	const lines = createInterface({
		input: createReadStream(logFile),
		crlfDelay: Infinity,
	});
	const tail: string[] = [];
	const maximumLines = 100;
	for await (const line of lines) {
		tail.push(line);
		if (tail.length > maximumLines) {
			tail.shift();
		}
	}
	if (tail.length > 0) {
		console.error(tail.join("\n"));
	}
}

/** Preserve command output without buffering large test logs in memory. */
async function execute({ args, logFile }: ExecuteOptions): Promise<number> {
	const [executable, ...argumentsList] = args;
	if (!executable) {
		throw new Error("Missing executable.");
	}

	const log = await open(logFile, "w");
	try {
		return await new Promise<number>((resolve, reject) => {
			const child = spawn(executable, argumentsList, {
				stdio: ["inherit", log.fd, log.fd],
			});
			function interrupt(): void {
				child.kill("SIGINT");
			}

			function terminate(): void {
				child.kill("SIGTERM");
			}

			process.once("SIGINT", interrupt);
			process.once("SIGTERM", terminate);

			child.once("error", reject);
			child.once("close", (code, signal) => {
				process.removeListener("SIGINT", interrupt);
				process.removeListener("SIGTERM", terminate);
				if (code !== null) {
					resolve(code);
					return;
				}

				if (signal !== null) {
					const shellSignalExitOffset = 128;
					resolve(shellSignalExitOffset + constants.signals[signal]);
					return;
				}

				resolve(1);
			});
		});
	} finally {
		await log.close();
	}
}

/** Repeat sequentially and retain every log; the first failure ends the loop. */
export async function run(options: Options): Promise<number> {
	const args = await commandArguments(options);
	const millisecondsPerSecond = 1000;
	const directory = await mkdtemp(join(tmpdir(), "run-it-"));
	console.log(`Logs: ${directory}`);

	for (let attempt = 1; attempt <= options.runs; attempt++) {
		const logFile = join(directory, `run-${attempt}.log`);
		const started = performance.now();
		const code = await execute({ args, logFile });
		const elapsedMilliseconds = performance.now() - started;
		const seconds = Math.floor(elapsedMilliseconds / millisecondsPerSecond);

		if (code !== 0) {
			await printFailure(logFile);
			console.error(
				`Run ${attempt}/${options.runs} failed after ${seconds}s (exit ${code})`,
			);
			console.error(`Full log: ${logFile}`);
			return code;
		}
		console.log(`Run ${attempt}/${options.runs} passed in ${seconds}s`);
	}
	return 0;
}
