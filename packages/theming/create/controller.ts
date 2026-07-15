import { spawn } from "child_process";
import { ghosttyApp } from "./apps/ghostty";
import { nvimApp } from "./apps/nvim";
import { ohMyZshApp } from "./apps/oh-my-zsh";
import { opencodeApp } from "./apps/opencode";
import { vscodeApp } from "./apps/vscode";
import { PATHS } from "./paths";
import type { CreateInstallModule } from "./types";
import { parseCssTokens } from "./utils";

const APPS: CreateInstallModule[] = [
	vscodeApp,
	opencodeApp,
	ghosttyApp,
	nvimApp,
	ohMyZshApp,
];

async function runCommand(command: string, args: string[]) {
	await new Promise<void>((resolve, reject) => {
		const child = spawn(command, args, {
			cwd: PATHS.root,
			stdio: "inherit",
			env: process.env,
		});

		child.on("error", reject);
		child.on("exit", (code) => {
			if (code === 0) {
				resolve();
				return;
			}
			reject(
				new Error(`${command} ${args.join(" ")} failed with exit code ${code}`),
			);
		});
	});
}

async function run() {
	await runCommand("npm", [
		"--prefix",
		"packages/theming/vsce-package",
		"install",
	]);

	const tokens = await parseCssTokens(PATHS.tokens);

	const created: Array<{ app: string; files: string[] }> = [];
	for (const app of APPS) {
		const files = await app.create(tokens);
		created.push({ app: app.appName, files });
	}

	const installed: Array<{ app: string; files: string[] }> = [];
	for (const app of APPS) {
		const files = await app.install();
		installed.push({ app: app.appName, files });
	}

	const report: string[] = [
		"Theme generation complete.",
		"",
		"Created in packages/theming/output:",
	];
	created.forEach((entry) => {
		report.push(`- ${entry.app}`);
		entry.files.forEach((file) => report.push(`  ${file}`));
	});

	report.push("", "Installed to app locations:");
	installed.forEach((entry) => {
		report.push(`- ${entry.app}`);
		entry.files.forEach((file) => report.push(`  ${file}`));
	});

	await runCommand("npm", [
		"--prefix",
		"packages/theming/vsce-package",
		"run",
		"install:codium",
	]);

	console.log(report.join("\n"));
}

run().catch((error) => {
	console.error(error);
	process.exit(1);
});
