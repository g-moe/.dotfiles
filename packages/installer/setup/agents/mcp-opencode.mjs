// Register the shared MCP command without the interactive `opencode mcp add`.
// OpenCode uses an mcp object and a command array. Edit only the named server
// with jsonc-parser so user comments and other settings remain intact. Write
// through configuration symlinks and keep the existing file permissions.
// https://opencode.ai/docs/cli/#mcp
// https://opencode.ai/docs/mcp-servers/#local

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { applyEdits, modify, parse } from "jsonc-parser";

function isObject(value) {
	return value !== null && typeof value === "object" && !Array.isArray(value);
}

function configPath() {
	// A custom directory loads after the explicit file in OpenCode.
	if (!process.env.OPENCODE_CONFIG_DIR && process.env.OPENCODE_CONFIG) {
		return process.env.OPENCODE_CONFIG;
	}
	const directory =
		process.env.OPENCODE_CONFIG_DIR ||
		path.join(
			process.env.XDG_CONFIG_HOME || path.join(os.homedir(), ".config"),
			"opencode",
		);
	// JSONC overrides JSON in OpenCode. Update the active file and retain comments.
	for (const filename of ["opencode.jsonc", "opencode.json"]) {
		const candidate = path.join(directory, filename);
		if (fs.lstatSync(candidate, { throwIfNoEntry: false })) return candidate;
	}
	return path.join(directory, "opencode.json");
}

function readConfig(target) {
	const text = fs.existsSync(target) ? fs.readFileSync(target, "utf8") : "{}\n";
	const errors = [];
	const config = parse(text, errors, { allowTrailingComma: true });
	if (errors.length)
		throw new Error("OpenCode configuration has invalid JSONC");
	if (!isObject(config))
		throw new Error("OpenCode configuration must be an object");
	if (config.mcp !== undefined && !isObject(config.mcp)) {
		throw new Error("OpenCode mcp must be an object");
	}
	return text;
}

function writeConfig(target, text) {
	fs.mkdirSync(path.dirname(target), { recursive: true });
	// Write beside the resolved target. Rename keeps user symlinks intact.
	const temporary = `${target}.${process.pid}.tmp`;
	try {
		fs.writeFileSync(temporary, text, { mode: 0o600 });
		if (fs.existsSync(target))
			fs.chmodSync(temporary, fs.statSync(target).mode);
		fs.renameSync(temporary, target);
	} finally {
		if (fs.existsSync(temporary)) fs.unlinkSync(temporary);
	}
}

function main([operation, name, command, ...args]) {
	const configuredPath = configPath();
	const target = fs
		.lstatSync(configuredPath, { throwIfNoEntry: false })
		?.isSymbolicLink()
		? fs.realpathSync(configuredPath)
		: configuredPath;
	const text = readConfig(target);
	if (operation === "validate") return;
	if (operation !== "merge" || !name || !command) {
		throw new Error("Use: mcp-opencode.mjs merge <name> <command> [args...]");
	}
	const edits = modify(
		text,
		["mcp", name],
		{
			type: "local",
			command: [command, ...args],
			enabled: true,
		},
		{ formattingOptions: { insertSpaces: true, tabSize: 2 } },
	);
	writeConfig(target, applyEdits(text, edits));
}

main(process.argv.slice(2));
