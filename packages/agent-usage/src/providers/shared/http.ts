import { asJsonObject, type JsonObject } from "../../domain/json.js";

export async function getJson(
	url: string,
	headers: Record<string, string>,
): Promise<JsonObject> {
	return requestJson(url, { headers });
}

export async function postJson(
	url: string,
	headers: Record<string, string>,
): Promise<JsonObject> {
	return requestJson(url, {
		method: "POST",
		headers,
		body: "{}",
	});
}

async function requestJson(
	url: string,
	request: RequestInit,
): Promise<JsonObject> {
	const response = await fetch(url, {
		...request,
		signal: AbortSignal.timeout(10_000),
	});
	if (!response.ok)
		throw new Error(`Request failed with HTTP ${response.status}`);
	const body: unknown = await response.json();
	const parsed = asJsonObject(body);
	if (!parsed) throw new Error("Provider returned an invalid response");
	return parsed;
}
