import assert from "node:assert/strict";
import test from "node:test";
import { Time } from "../src/time-values.ts";

test("parses Unix milliseconds", () => {
	assert.deepEqual(Time.parseUnixMs(" 0 "), { ok: true, value: 0 });
	assert.deepEqual(Time.parseUnixMs("-1"), { ok: true, value: -1 });
});

test("rejects invalid Unix milliseconds", () => {
	assert.equal(Time.parseUnixMs("").ok, false);
	assert.equal(Time.parseUnixMs("1.5").ok, false);
	assert.equal(Time.parseUnixMs("tomorrow").ok, false);
	assert.equal(Time.parseUnixMs("9007199254740991").ok, false);
});

test("formats UTC and a selected time zone", () => {
	const formats = Time.formats(0, "America/Chicago");
	const iso = formats.find((format) => format.id === "iso-8601");
	const timeZone = formats.find((format) => format.id === "time-zone");
	const utcOffset = formats.find((format) => format.id === "utc-offset");

	assert.deepEqual(iso, {
		id: "iso-8601",
		label: "ISO 8601",
		utc: "1970-01-01T00:00:00.000Z",
		zoned: "1969-12-31T18:00:00.000-06:00",
	});
	assert.equal(timeZone?.zoned, "America/Chicago");
	assert.equal(utcOffset?.zoned, "UTC-06:00");
	assert.deepEqual(
		formats.map((format) => format.label),
		["Datetime", "Date", "Clock", "ISO 8601", "Timezone", "UTC-Offset"],
	);
});

test("uses the selected time zone's daylight-saving offset", () => {
	const summer = Time.formats(
		Date.parse("2026-08-10T12:00:00.000Z"),
		"America/Chicago",
	);
	const utcOffset = summer.find((format) => format.id === "utc-offset");

	assert.equal(utcOffset?.zoned, "UTC-05:00");
});
