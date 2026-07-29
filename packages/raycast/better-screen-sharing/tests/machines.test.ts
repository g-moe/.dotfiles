import assert from "node:assert/strict";
import test from "node:test";
import { configuredMachines } from "../src/machines.ts";

test("configuredMachines trims complete slots and ignores incomplete slots", () => {
	assert.deepEqual(
		configuredMachines({
			machine1Name: " Office Mac ",
			machine1Address: " office-mac.local ",
			machine2Name: "Home PC",
			machine2Address: "192.168.1.100",
			machine3Name: "missing address",
			machine4Address: "missing name",
		}),
		[
			{ name: "Office Mac", address: "office-mac.local" },
			{ name: "Home PC", address: "192.168.1.100" },
		],
	);
});
