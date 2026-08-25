import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import test from "node:test";

test("CLI rejects all arguments before it contacts providers", () => {
	const result = spawnSync(
		process.execPath,
		["--import", "tsx", "src/cli/main.ts", "--unsupported"],
		{
			cwd: new URL("../", import.meta.url),
			encoding: "utf8",
		},
	);
	assert.equal(result.status, 2);
	assert.equal(result.stdout, "");
	assert.equal(result.stderr, "agent-usage does not accept arguments\n");
});
