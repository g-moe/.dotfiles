import { execFileSync, spawnSync } from "node:child_process";
import { chmodSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";

export function readJsonFile(path: string): unknown {
	return JSON.parse(readFileSync(expandHome(path), "utf8")) as unknown;
}

export function expandHome(path: string): string {
	return path === "~"
		? homedir()
		: path.startsWith("~/")
			? `${homedir()}/${path.slice(2)}`
			: path;
}

export function readMacKeychain(service: string): string | undefined {
	if (process.platform !== "darwin") return undefined;
	try {
		const value = execFileSync(
			"security",
			["find-generic-password", "-s", service, "-w"],
			{
				encoding: "utf8",
				stdio: ["ignore", "pipe", "ignore"],
			},
		).trim();
		return value || undefined;
	} catch {
		return undefined;
	}
}

export function writeMacKeychain(service: string, value: string): void {
	const metadata = spawnSync(
		"security",
		["find-generic-password", "-s", service],
		{
			encoding: "utf8",
		},
	);
	const account =
		`${metadata.stdout}${metadata.stderr}`.match(
			/"acct"<blob>="([^"]*)"/,
		)?.[1] ?? "";
	const result = spawnSync(
		"security",
		["add-generic-password", "-U", "-s", service, "-a", account, "-w", value],
		{ stdio: "ignore" },
	);
	if (result.status !== 0)
		throw new Error("Could not update the macOS Keychain credential");
}

export function writePrivateFile(path: string, value: string): void {
	const expanded = expandHome(path);
	const temporary = `${expanded}.agent-usage.tmp`;
	writeFileSync(temporary, value, { encoding: "utf8", mode: 0o600 });
	chmodSync(temporary, 0o600);
	renameSync(temporary, expanded);
}
