import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, mock, test } from "node:test";
import { expandHome, writePrivateFile } from "../src/providers/shared/files.ts";
import { getJson, postJson } from "../src/providers/shared/http.ts";

const TEMPORARY_DIRECTORY = mkdtempSync(join(tmpdir(), "agent-usage-test-"));

after(() => rmSync(TEMPORARY_DIRECTORY, { recursive: true }));

test("private file writer replaces content with owner-only permissions", () => {
	const path = join(TEMPORARY_DIRECTORY, "credentials.json");
	writePrivateFile(path, '{"token":"value"}\n');
	assert.equal(readFileSync(path, "utf8"), '{"token":"value"}\n');
	assert.equal(statSync(path).mode & 0o777, 0o600);
});

test("home expansion changes only a leading tilde path segment", () => {
	assert.notEqual(expandHome("~/credentials.json"), "~/credentials.json");
	assert.equal(
		expandHome("path/~/credentials.json"),
		"path/~/credentials.json",
	);
});

test("HTTP helpers send the correct methods and parse JSON objects", async () => {
	const requests: { input: string; method: string }[] = [];
	mock.method(
		globalThis,
		"fetch",
		async (input: RequestInfo | URL, request?: RequestInit) => {
			requests.push({
				input: String(input),
				method: request?.method ?? "GET",
			});
			return Response.json({ value: 1 });
		},
	);
	try {
		assert.deepEqual(await getJson("https://example.test/get", {}), {
			value: 1,
		});
		assert.deepEqual(await postJson("https://example.test/post", {}), {
			value: 1,
		});
		assert.deepEqual(requests, [
			{ input: "https://example.test/get", method: "GET" },
			{ input: "https://example.test/post", method: "POST" },
		]);
	} finally {
		mock.restoreAll();
	}
});

test("HTTP helpers reject failed and non-object responses", async () => {
	mock.method(
		globalThis,
		"fetch",
		async () => new Response("error", { status: 503 }),
	);
	await assert.rejects(getJson("https://example.test/status", {}), /HTTP 503/);
	mock.restoreAll();

	mock.method(globalThis, "fetch", async () => Response.json([]));
	await assert.rejects(
		getJson("https://example.test/json", {}),
		/invalid response/,
	);
	mock.restoreAll();
});
