import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const homeDir = os.homedir();
const sourceDir = path.join(homeDir, ".config", ".agents", "skills");
const targetDirs = [
	path.join(homeDir, ".agents", "skills"),
	path.join(homeDir, ".codex", "skills"),
	path.join(homeDir, ".claude", "skills"),
	path.join(homeDir, ".cursor", "skills"),
	path.join(homeDir, ".config", "opencode", "skills"),
];

for (const targetDir of targetDirs) {
	fs.mkdirSync(targetDir, { recursive: true });

	for (const entry of fs.readdirSync(sourceDir, { withFileTypes: true })) {
		if (!entry.isDirectory()) continue;

		const source = path.join(sourceDir, entry.name);
		if (!fs.existsSync(path.join(source, "SKILL.md"))) continue;

		const target = path.join(targetDir, entry.name);
		const targetStat = fs.lstatSync(target, { throwIfNoEntry: false });

		if (targetStat && !targetStat.isSymbolicLink()) {
			throw new Error(`Refusing to replace non-symlink: ${target}`);
		}

		if (targetStat?.isSymbolicLink()) {
			fs.unlinkSync(target);
		}

		fs.symlinkSync(source, target, "dir");
		console.log(`linked ${target} -> ${source}`);
	}
}
