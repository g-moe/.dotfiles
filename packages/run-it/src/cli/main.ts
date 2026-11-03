#!/usr/bin/env node
import { parseOptions, USAGE, type Options } from "../options.js";
import { run } from "../run.js";

function printHelp(): void {
	console.log(`Options:
  --runs=N    Required. Number of runs (positive integer).
  --cpu=N     Limit the command and its children to N CPUs (Linux).
  --mem=N     Limit total memory to N GiB, with swap disabled (Linux).
  -h, --help  Show this help.

Examples:
  run-it "pnpm run tests --force" --runs=10
  run-it "pnpm run tests --force" --runs=10 --cpu=2 --mem=8`);
}

function reportError(error: unknown): void {
	if (error instanceof Error) {
		console.error(error.message);
	} else {
		console.error(String(error));
	}
}

async function main(): Promise<number> {
	const args = process.argv.slice(2);
	const noArguments = args.length === 0;
	const helpRequested =
		args.length === 1 && (args[0] === "--help" || args[0] === "-h");

	if (noArguments || helpRequested) {
		printHelp();
		return 0;
	}

	const invalidArguments = 2;
	const executionFailure = 1;
	let options: Options;

	try {
		options = parseOptions(args);
	} catch (error) {
		reportError(error);
		console.error(USAGE);
		return invalidArguments;
	}

	try {
		return await run(options);
	} catch (error) {
		reportError(error);
		return executionFailure;
	}
}

process.exitCode = await main();
