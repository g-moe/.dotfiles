import fs from "node:fs";
import path from "node:path";

function isObject(value) {
	return value !== null && typeof value === "object" && !Array.isArray(value);
}

function resolveTarget(configPath) {
	if (fs.existsSync(configPath) && fs.lstatSync(configPath).isSymbolicLink()) {
		return fs.realpathSync(configPath);
	}
	return configPath;
}

function readConfig(target) {
	const config = fs.existsSync(target)
		? JSON.parse(fs.readFileSync(target, "utf8"))
		: {};
	if (!isObject(config))
		throw new Error("Cursor MCP configuration must be an object");
	if (config.mcpServers === undefined) config.mcpServers = {};
	if (!isObject(config.mcpServers)) {
		throw new Error("Cursor mcpServers must be an object");
	}
	return config;
}

function writeConfig(target, config) {
	fs.mkdirSync(path.dirname(target), { recursive: true });
	// Keep the temporary file beside the target so rename is atomic. When the
	// configured path is a symlink, target is its resolved file and the link stays.
	const temporary = `${target}.${process.pid}.tmp`;
	try {
		fs.writeFileSync(temporary, `${JSON.stringify(config, null, 2)}\n`, {
			mode: 0o600,
		});
		if (fs.existsSync(target))
			fs.chmodSync(temporary, fs.statSync(target).mode);
		fs.renameSync(temporary, target);
	} finally {
		if (fs.existsSync(temporary)) fs.unlinkSync(temporary);
	}
}

function main([operation, configPath, name, command, ...args]) {
	if (!configPath) throw new Error("Cursor MCP configuration path is required");
	const target = resolveTarget(configPath);
	const config = readConfig(target);
	if (operation === "validate") return;
	if (operation !== "merge" || !name || !command) {
		throw new Error(
			"Use: mcp-cursor.mjs merge <config> <name> <command> [args...]",
		);
	}
	config.mcpServers[name] = { command, args };
	writeConfig(target, config);
}

main(process.argv.slice(2));
