import { z } from "zod";

const unixMsSchema = z
	.string()
	.trim()
	.min(1, "Enter a Unix millisecond timestamp")
	.regex(/^-?\d+$/, "Unix milliseconds must be a whole number")
	.transform(Number)
	.refine(Number.isSafeInteger, "Unix milliseconds are outside the safe range")
	.refine(
		(value) => !Number.isNaN(new Date(value).getTime()),
		"Unix milliseconds are outside the supported date range",
	);

export type TimeFormat = {
	id: string;
	label: string;
	utc: string;
	zoned: string;
};

export type ParsedUnixMs =
	| { ok: true; value: number }
	| { ok: false; error: string };

function parseUnixMs(input: string): ParsedUnixMs {
	const result = unixMsSchema.safeParse(input);

	if (!result.success) {
		return { ok: false, error: result.error.issues[0].message };
	}

	return { ok: true, value: result.data };
}

function dateTime(value: number, timeZone: string) {
	return new Intl.DateTimeFormat("en-US", {
		timeZone,
		year: "numeric",
		month: "short",
		day: "2-digit",
		hour: "2-digit",
		minute: "2-digit",
		second: "2-digit",
		hourCycle: "h23",
	}).format(value);
}

function date(value: number, timeZone: string) {
	return new Intl.DateTimeFormat("en-US", {
		timeZone,
		dateStyle: "full",
	}).format(value);
}

function time(value: number, timeZone: string) {
	return new Intl.DateTimeFormat("en-US", {
		timeZone,
		timeStyle: "long",
		hourCycle: "h23",
	}).format(value);
}

function offset(value: number, timeZone: string) {
	const name = new Intl.DateTimeFormat("en-US", {
		timeZone,
		timeZoneName: "longOffset",
	})
		.formatToParts(value)
		.find((part) => part.type === "timeZoneName")?.value;

	if (!name || name === "GMT") {
		return "+00:00";
	}

	return name.replace("GMT", "");
}

function zonedIso(value: number, timeZone: string) {
	const parts = new Intl.DateTimeFormat("en-CA", {
		timeZone,
		year: "numeric",
		month: "2-digit",
		day: "2-digit",
		hour: "2-digit",
		minute: "2-digit",
		second: "2-digit",
		fractionalSecondDigits: 3,
		hourCycle: "h23",
	}).formatToParts(value);
	const part = (type: Intl.DateTimeFormatPartTypes) =>
		parts.find((candidate) => candidate.type === type)?.value ?? "";

	return `${part("year")}-${part("month")}-${part("day")}T${part("hour")}:${part("minute")}:${part("second")}.${part("fractionalSecond")}${offset(value, timeZone)}`;
}

function formats(value: number, timeZone: string): TimeFormat[] {
	const instant = new Date(value);

	return [
		{
			id: "date-time",
			label: "Datetime",
			utc: dateTime(value, "UTC"),
			zoned: dateTime(value, timeZone),
		},
		{
			id: "date",
			label: "Date",
			utc: date(value, "UTC"),
			zoned: date(value, timeZone),
		},
		{
			id: "time",
			label: "Clock",
			utc: time(value, "UTC"),
			zoned: time(value, timeZone),
		},
		{
			id: "iso-8601",
			label: "ISO 8601",
			utc: instant.toISOString(),
			zoned: zonedIso(value, timeZone),
		},
		{
			id: "time-zone",
			label: "Timezone",
			utc: "UTC",
			zoned: timeZone,
		},
		{
			id: "utc-offset",
			label: "UTC-Offset",
			utc: "UTC+00:00",
			zoned: `UTC${offset(value, timeZone)}`,
		},
	];
}

export const Time = {
	formats,
	parseUnixMs,
} as const;
