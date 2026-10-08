// Generate a Cursor plugin from the shared AGENTS.md. Cursor rules need MDC
// frontmatter, and local plugins cannot link to a repository outside their
// folder. Keep the full instruction text in the rule; a path reference does
// not load that text into every prompt. The installer refreshes this copy.
// CLI and T3 ACP loading still need a live check.
// https://cursor.com/docs/plugins
// https://cursor.com/docs/rules

import fs from "node:fs";
import path from "node:path";

const pluginName = "garrett-instructions";

function pluginFiles(instructions) {
	return [
		[
			".cursor-plugin/plugin.json",
			`${JSON.stringify({ name: pluginName, rules: "rules" }, null, 2)}\n`,
		],
		[
			"rules/global.mdc",
			`---\ndescription: Garrett's global instructions\nalwaysApply: true\n---\n\n${instructions}`,
		],
	];
}

function rejectSymlinks(home, target) {
	const relative = path.relative(home, target);
	let current = home;
	for (const part of relative.split(path.sep)) {
		current = path.join(current, part);
		const entry = fs.lstatSync(current, { throwIfNoEntry: false });
		if (entry?.isSymbolicLink()) {
			throw new Error(`Cursor plugin path must not be a symlink: ${current}`);
		}
	}
}

function main([operation, source, home]) {
	if (!["write", "check"].includes(operation) || !source || !home) {
		throw new Error(
			"Use: cursor-rules.mjs <write|check> <instructions> <home>",
		);
	}
	const instructions = fs.readFileSync(source, "utf8");
	if (!instructions.trim())
		throw new Error("Global agent instructions are empty");
	const plugin = path.resolve(home, ".cursor/plugins/local", pluginName);
	const files = pluginFiles(instructions);

	// Validate every destination before writes so a bad rule path cannot leave a
	// partial plugin or write outside the user-owned plugin directory.
	for (const [relative] of files) {
		rejectSymlinks(path.resolve(home), path.join(plugin, relative));
	}
	const manifest = path.join(plugin, files[0][0]);
	if (fs.existsSync(manifest)) {
		const existing = JSON.parse(fs.readFileSync(manifest, "utf8"));
		if (existing.name !== pluginName) {
			throw new Error(`Cursor plugin has another owner: ${manifest}`);
		}
	}

	for (const [relative, content] of files) {
		const target = path.join(plugin, relative);
		if (operation === "write") {
			fs.mkdirSync(path.dirname(target), { recursive: true });
			fs.writeFileSync(target, content);
		} else if (
			!fs.existsSync(target) ||
			fs.readFileSync(target, "utf8") !== content
		) {
			throw new Error(
				`Cursor global instructions are missing or stale: ${target}`,
			);
		}
	}
}

main(process.argv.slice(2));
