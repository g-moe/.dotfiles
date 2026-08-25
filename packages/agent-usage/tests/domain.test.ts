import assert from "node:assert/strict";
import test from "node:test";
import {
	asFiniteNumber,
	asJsonArray,
	asJsonObject,
	asNonEmptyString,
} from "../src/domain/json.ts";
import { parseDateTime, parseUsedPercent } from "../src/domain/usage.ts";

test("JSON converters accept only their documented value types", () => {
	assert.deepEqual(asJsonObject({ value: 1 }), { value: 1 });
	assert.equal(asJsonObject([]), undefined);
	assert.deepEqual(asJsonArray([1, 2]), [1, 2]);
	assert.deepEqual(asJsonArray("invalid"), []);
	assert.equal(asNonEmptyString(" value "), " value ");
	assert.equal(asNonEmptyString("  "), undefined);
	assert.equal(asFiniteNumber("12.5"), 12.5);
	assert.equal(asFiniteNumber("  "), undefined);
	assert.equal(asFiniteNumber("invalid"), undefined);
});

test("date-time parser accepts seconds, milliseconds, and ISO text", () => {
	const expected = "2027-01-15T08:00:00.000Z";
	assert.equal(parseDateTime(1_800_000_000)?.toISOString(), expected);
	assert.equal(parseDateTime(1_800_000_000_000)?.toISOString(), expected);
	assert.equal(parseDateTime(expected)?.toISOString(), expected);
	assert.equal(parseDateTime("invalid"), undefined);
});

test("used-percent parser rejects negative values and caps values at 100", () => {
	assert.equal(parseUsedPercent("12.5"), 12.5);
	assert.equal(parseUsedPercent(125), 100);
	assert.equal(parseUsedPercent("  "), undefined);
	assert.equal(parseUsedPercent(-1), undefined);
	assert.equal(parseUsedPercent("invalid"), undefined);
});
