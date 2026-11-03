import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { parseOptions } from "../src/options.ts";
import { parseCpuList } from "../src/limits.ts";

test("requires runs and rejects invalid resource limits", () => {
	for (const args of [
		[],
		["true"],
		["true", "--runs=0"],
		["true", "--runs=1", "--cpu=-1"],
		["true", "--runs=1", "--mem=1.5"],
		["true", "--runs=1", "--unknown=2"],
		["true", "false", "--runs=1"],
	]) {
		assert.throws(() => parseOptions(args));
	}
	assert.deepEqual(parseOptions(["printf 'hello world'", "--runs=2"]), {
		command: "printf 'hello world'",
		runs: 2,
		cpu: undefined,
		memoryGb: undefined,
	});
});

test("expands sparse CPU affinity without choosing disallowed CPUs", () => {
	assert.deepEqual(parseCpuList("2-3,7,10-12"), [2, 3, 7, 10, 11, 12]);
	assert.throws(() => parseCpuList("3-1"));
});

test("executes pipelines repeatedly, preserves logs, and stops on first failure", () => {
	const directory = mkdtempSync(join(tmpdir(), "run-it-test-"));
	try {
		const invoke = (command: string) =>
			spawnSync(
				process.execPath,
				["--import", "tsx", "src/cli/main.ts", command, "--runs=3"],
				{
					cwd: new URL("../", import.meta.url),
					encoding: "utf8",
					env: { ...process.env, TMPDIR: directory, SHELL: "/bin/sh" },
				},
			);
		const success = invoke("printf 'hello world' | cat");
		assert.equal(success.status, 0, success.stderr);
		assert.match(success.stdout, /Run 3\/3 passed/);
		const logs = /^Logs: (.+)$/m.exec(success.stdout)?.[1];
		assert.ok(logs);
		assert.equal(readFileSync(join(logs, "run-3.log"), "utf8"), "hello world");

		const failure = invoke("echo broken >&2; exit 7");
		assert.equal(failure.status, 7);
		assert.match(failure.stderr, /broken/);
		assert.match(failure.stderr, /Run 1\/3 failed/);
		assert.doesNotMatch(failure.stdout + failure.stderr, /Run 2\/3/);
	} finally {
		rmSync(directory, { recursive: true, force: true });
	}
});

for (const args of [[], ["--help"], ["-h"]]) {
	test(`prints help without running a command: ${args.join(" ") || "no arguments"}`, () => {
		const result = spawnSync(
			process.execPath,
			["--import", "tsx", "src/cli/main.ts", ...args],
			{
				cwd: new URL("../", import.meta.url),
				encoding: "utf8",
			},
		);

		assert.equal(result.status, 0);
		assert.equal(result.stderr, "");
		assert.match(result.stdout, /^Options:/);
		assert.match(result.stdout, /--runs=N/);
		assert.match(result.stdout, /--cpu=N/);
		assert.match(result.stdout, /--mem=N/);
		assert.match(result.stdout, /Examples:/);
		assert.doesNotMatch(result.stdout, /Logs:/);
	});
}
