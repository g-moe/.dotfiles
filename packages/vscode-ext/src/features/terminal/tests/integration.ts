import assert from "node:assert/strict";
import * as vscode from "vscode";

import { COMMANDS } from "../../../commands";

export interface Checkpoint {
	phase: "before" | "after";
	column: number;
	input: string;
	maximize: boolean;
	groups: number;
	command?: string;
	surface?: string;
	cold?: boolean;
	elapsedMs?: number;
	budgetMs?: number;
	state?: string;
}

export interface TestDriver {
	start(name: string): void;
	checkpoint(check: Checkpoint): Promise<void>;
	pass(): Promise<void>;
}

const command = COMMANDS.terminal.focus;
const commandInput = (currentMaximized: boolean) => ({ currentMaximized });
type Start =
	| "visible"
	| "covered"
	| "other"
	| "absent"
	| "panel"
	| "moved"
	| "unpinned";

export async function run(driver: TestDriver) {
	assert.ok(
		process.env.BETTER_VSCODE_TEST_REPORT,
		"Run only in the isolated browser test workspace",
	);
	await vscode.extensions.getExtension("gary-ix.better-vscode")!.activate();

	// Exercise layouts that hide the editor or restrict where tabs can open.
	for (const [state, surface] of [
		["sidebars-00", "editor"],
		["sidebars-10", "editor"],
		["sidebars-01", "editor"],
		["sidebars-11", "editor"],
		["other-maximized", "editor"],
		["other-maximized", "explorer"],
		["other-maximized", "scm"],
		["owned-maximized", "scm"],
		["owned-locked-maximized", "explorer"],
		["moved-locked-maximized", "scm"],
		["first-locked-cold", "scm"],
		["panel-maximized", "panel-terminal"],
		["sidebar-maximized", "panel-terminal"],
	] as const) {
		await workbenchScenario(state, surface);
	}

	// Keep one shell alive for each set of five warm calls.
	for (const maximize of [false, true]) {
		for (const surface of ["search", "explorer"]) {
			await surfaceScenario(surface, 2, false, maximize, 5);
		}
	}

	await scenario("TwoColumns", 2, "visible", false);
	await scenario("TwoColumns", 2, "other", true);
	await scenario("TwoByTwoGrid", 4, "covered", false);
	await scenario("TwoByTwoGrid", 4, "covered", true);
	await scenario("ThreeColumns", 3, "absent", false);
	await scenario("ThreeColumns", 3, "absent", true);
	await scenario("ThreeColumns", 3, "panel", false);
	await scenario("ThreeColumns", 3, "moved", true);
	await scenario("Single", 1, "absent", false);

	// Lifecycle cases change shell identity; the layout cases reuse the same shell.
	for (const action of [
		"concurrent",
		"closed",
		"ambiguous",
		"repeat-maximize",
	] as const) {
		driver.start(`lifecycle / ${action}`);

		const fixture = await setup("TwoColumns", 2);

		await vscode.commands.executeCommand(command, commandInput(false));

		let terminal = vscode.window.activeTerminal!;
		const original = terminal;
		const pid = await terminal.processId;

		if (action === "closed") {
			terminal.dispose();
			await until(
				async () => !(await liveTerminals()).includes(terminal),
				"shell must close before recreation",
			);
		}

		if (action === "ambiguous") {
			await vscode.commands.executeCommand(
				"workbench.action.terminal.renameWithArg",
				{ name: fixture.other.name },
			);
			await until(
				() => terminal.name === fixture.other.name,
				"rename must settle",
			);
		}

		await fixture.code(2);
		await driver.checkpoint({
			phase: "before",
			column: 2,
			input: "fixture-2.txt",
			maximize: false,
			groups: 2,
		});

		if (action === "ambiguous") {
			const before = snapshot();

			await assert.rejects(
				async () =>
					vscode.commands.executeCommand(command, commandInput(false)),
				/same name/,
			);
			assert.deepEqual(
				snapshot(),
				before,
				"rejected command must not move tabs or create a shell",
			);
			terminal.show();
			await until(
				() => ownedTab(terminal)?.isActive === true,
				"owned terminal selected for rename",
			);
			await vscode.commands.executeCommand(
				"workbench.action.terminal.renameWithArg",
				{ name: "Recovered Shell" },
			);
			await until(() => terminal.name === "Recovered Shell", "recovery rename");
		}

		const maximize = action === "repeat-maximize";
		const cold = action === "closed";
		// Exclude fixture setup and browser handshakes from API batch timing.
		const started = performance.now();

		if (action === "concurrent") {
			await Promise.all(
				Array.from({ length: 10 }, () =>
					vscode.commands.executeCommand(command, commandInput(false)),
				),
			);
		} else {
			await vscode.commands.executeCommand(command, commandInput(maximize));

			if (action === "repeat-maximize") {
				await vscode.commands.executeCommand(command, commandInput(true));
			}
		}

		const elapsedMs = performance.now() - started;
		const budget = cold || action === "concurrent" ? 2000 : 500;

		terminal = vscode.window.activeTerminal!;

		if (cold) {
			assert.notEqual(terminal, original);
		} else {
			assert.equal(terminal, original);
			assert.equal(await terminal.processId, pid);
		}

		await result(terminal, fixture, maximize, {
			cold,
			elapsedMs,
			budgetMs: budget,
		});
	}

	async function workbenchScenario(state: string, surface: string) {
		const maximize =
			state === "other-maximized" ||
			state === "owned-maximized" ||
			state === "owned-locked-maximized" ||
			state === "moved-locked-maximized";

		driver.start(`${maximize ? "maximize" : "focus"} / ${surface} / ${state}`);

		const fixture = await setup("TwoColumns", 2);
		const cold = state === "first-locked-cold";
		let terminal: vscode.Terminal | undefined;

		if (!cold) {
			await vscode.commands.executeCommand(command, commandInput(false));
			terminal = vscode.window.activeTerminal!;
		}

		if (state === "moved-locked-maximized") {
			await vscode.commands.executeCommand("moveActiveEditor", {
				to: "last",
				by: "group",
			});
		}

		if (cold) {
			await fixture.code(1);
		}

		if (state.includes("locked")) {
			await vscode.commands.executeCommand("workbench.action.lockEditorGroup");
		}

		if (state === "other-maximized" || state.startsWith("sidebars-")) {
			await fixture.code(2);
		}

		if (
			state.endsWith("maximized") &&
			!state.startsWith("panel") &&
			!state.startsWith("sidebar")
		) {
			await vscode.commands.executeCommand(
				COMMANDS.workbench.toggleMaximizeEditorGroup,
				commandInput(false),
			);
		}

		if (state === "panel-maximized" || state === "sidebar-maximized") {
			await fixture.code(2);
			fixture.other.show();

			if (state === "sidebar-maximized") {
				await vscode.commands.executeCommand(
					"workbench.action.movePanelToSecondarySideBar",
				);
				await vscode.commands.executeCommand(
					"workbench.action.maximizeAuxiliaryBar",
				);
			} else {
				await vscode.commands.executeCommand(
					"workbench.action.toggleMaximizedPanel",
				);
			}
		}

		const before = snapshot().filter((t) => t.name !== terminal?.name);

		await driver.checkpoint({
			phase: "before",
			column: 1,
			groups: 2,
			input: surface === "editor" ? "fixture-2.txt" : "terminal",
			maximize,
			command,
			surface,
			cold,
			state,
		});

		const actual = vscode.window.activeTerminal!;

		assertTerminal(actual);

		if (terminal) {
			assert.equal(actual, terminal, "reuse the existing shell");
		}

		assert.deepEqual(
			snapshot().filter((t) => t.name !== actual.name),
			before,
			"preserve other tabs and pins",
		);
		await result(actual, fixture, maximize, { cold });
	}

	// The browser driver sets the actual starting keyboard focus and invokes
	// a public hotkey. API active-editor state alone cannot prove input focus.
	async function surfaceScenario(
		surface: string,
		column: number,
		cold: boolean,
		maximize: boolean,
		repetitions = 1,
		ownedView?: "visible" | "covered",
	) {
		const fixture = await setup("TwoColumns", 2);
		let terminal: vscode.Terminal | undefined;

		if (!cold) {
			await vscode.commands.executeCommand(command, commandInput(false));
			terminal = vscode.window.activeTerminal!;
			assertTerminal(terminal);
		}

		const output =
			surface === "output"
				? vscode.window.createOutputChannel("Better VS Code Test Output")
				: undefined;

		try {
			output?.appendLine("Better VS Code output focus fixture");

			for (let repetition = 1; repetition <= repetitions; repetition++) {
				driver.start(
					`${maximize ? "maximize" : "focus"} / ${surface} / group-${column} / ${cold ? "cold" : "warm"}${ownedView ? ` / owned-${ownedView}` : ""}${repetitions > 1 ? ` / repeat-${repetition}` : ""}`,
				);

				if (repetition > 1) {
					if (maximize) {
						await vscode.commands.executeCommand(
							COMMANDS.workbench.toggleMaximizeEditorGroup,
							commandInput(true),
						);
					}

					await vscode.commands.executeCommand(
						"workbench.action.editorLayoutTwoColumns",
					);
				}

				output?.show(true);

				if (surface === "panel-terminal") {
					fixture.other.show(true);
				}

				if (ownedView === "covered") {
					await fixture.code(1);
				}

				if (ownedView !== "visible") {
					await fixture.code(column);
				}

				if (ownedView) {
					assert.equal(
						ownedTab(terminal!)?.isActive,
						ownedView === "visible",
						"owned tab visibility before sidebar focus",
					);
				}

				if (maximize) {
					await vscode.commands.executeCommand(
						COMMANDS.workbench.toggleMaximizeEditorGroup,
						commandInput(false),
					);
				}

				const before = snapshot().filter((t) => t.name !== terminal?.name);

				await driver.checkpoint({
					phase: "before",
					column,
					input: `fixture-${column}.txt`,
					maximize,
					groups: 2,
					command,
					surface,
					cold,
				});
				await until(() => {
					try {
						assertTerminal(vscode.window.activeTerminal!);

						return true;
					} catch {
						return false;
					}
				}, "surface command must focus and pin the terminal");

				const actual = vscode.window.activeTerminal!;

				if (terminal) {
					assert.equal(
						actual,
						terminal,
						"surface command must reuse the shell",
					);
				}

				assert.deepEqual(
					snapshot().filter((t) => t.name !== actual.name),
					before,
					"surface command must preserve other tabs",
				);
				terminal = actual;
				await result(actual, fixture, maximize, { cold });
			}
		} finally {
			output?.dispose();
		}
	}

	async function scenario(
		layout: string,
		groups: number,
		start: Start,
		maximize: boolean,
	) {
		driver.start(`${maximize ? "maximize" : "focus"} / ${layout} / ${start}`);

		const fixture = await setup(layout, groups);
		let terminal: vscode.Terminal | undefined;

		if (start !== "absent") {
			await vscode.commands.executeCommand(command, commandInput(false));
			terminal = vscode.window.activeTerminal!;
			assertTerminal(terminal);
		}

		if (start === "covered") {
			await fixture.code(1);
		}

		if (start === "panel") {
			await vscode.commands.executeCommand(
				"workbench.action.terminal.moveToTerminalPanel",
			);
			await until(
				() => !ownedTab(terminal!),
				"owned terminal must leave editor area",
			);
			await vscode.commands.executeCommand("workbench.action.closePanel");
		}

		if (start === "moved" || start === "unpinned") {
			await vscode.commands.executeCommand("workbench.action.unpinEditor");
			await until(
				() => ownedTab(terminal!)?.isPinned === false,
				"owned tab must be unpinned",
			);

			if (start === "moved") {
				await vscode.commands.executeCommand("moveActiveEditor", {
					to: "last",
					by: "group",
				});
				await until(
					() => ownedTab(terminal!)?.group.viewColumn === groups,
					"owned tab must be in last group",
				);
			} else {
				await vscode.commands.executeCommand("moveActiveEditor", {
					to: "last",
					by: "tab",
				});
				await until(
					() => ownedTab(terminal!)?.group.tabs.at(-1) === ownedTab(terminal!),
					"owned tab must be last",
				);
			}
		}

		const column = start === "moved" ? 1 : groups;

		await fixture.code(column);

		let input = `fixture-${column}.txt`;

		if (start === "other") {
			fixture.other.show();
			await until(
				() => vscode.window.activeTerminal === fixture.other,
				"other terminal active",
			);
			await vscode.commands.executeCommand(
				"workbench.action.terminal.moveToEditor",
			);
			await until(
				() =>
					vscode.window.tabGroups.activeTabGroup.activeTab?.label ===
					fixture.other.name,
				"other terminal editor active",
			);
			assert.equal(vscode.window.tabGroups.activeTabGroup.viewColumn, column);
			input = fixture.other.name;
		}

		if (start === "visible" && groups > 1) {
			assert.equal(ownedTab(terminal!)?.isActive, true);
		}

		if (start === "covered") {
			assert.equal(ownedTab(terminal!)?.isActive, false);
		}

		assert.equal(vscode.window.tabGroups.activeTabGroup.viewColumn, column);

		if (maximize && groups > 1) {
			await vscode.commands.executeCommand(
				COMMANDS.workbench.toggleMaximizeEditorGroup,
				commandInput(false),
			);
		}

		const before = snapshot().filter((t) => t.name !== terminal?.name);

		await driver.checkpoint({
			phase: "before",
			column,
			input,
			maximize,
			groups,
			command,
			cold: start === "absent",
		});
		await until(() => {
			try {
				assertTerminal(vscode.window.activeTerminal!);

				return true;
			} catch {
				return false;
			}
		}, "public command must focus and pin the terminal");

		const actual = vscode.window.activeTerminal!;

		if (terminal) {
			assert.equal(actual, terminal, "must reuse the same shell object");
		}

		assert.deepEqual(
			snapshot().filter((t) => t.name !== actual.name),
			before,
			"other tabs must keep their group, order, and pin",
		);
		await result(actual, fixture, maximize, { cold: start === "absent" });
	}

	// Verify the API state before and after real typing in the browser.
	async function result(
		terminal: vscode.Terminal,
		fixture: Awaited<ReturnType<typeof setup>>,
		maximize: boolean,
		timing: { cold?: boolean; elapsedMs?: number; budgetMs?: number } = {},
	) {
		assertTerminal(terminal);
		assert.equal(
			(await liveTerminals()).length,
			2,
			"one owned shell and one unrelated shell",
		);
		assert.equal(
			fixture.other.exitStatus,
			undefined,
			"unrelated shell stays alive",
		);
		fixture.assertFiles();
		await driver.checkpoint({
			phase: "after",
			column: 1,
			input: terminal.name,
			maximize,
			groups: fixture.groups,
			...timing,
		});
		// Check again after real browser input. A transient API state must not pass.
		assertTerminal(terminal);
		fixture.assertFiles();
		await driver.pass();
	}
}

async function setup(layout: string, groups: number) {
	// Disposal changes the live list. Keep the cleanup targets fixed.
	await vscode.commands.executeCommand("workbench.action.resetViewLocations");
	await vscode.commands.executeCommand(
		"workbench.action.focusFirstEditorGroup",
	);

	// Closing tabs does not clear a group's lock. Reset each existing group.
	for (let index = 0; index < vscode.window.tabGroups.all.length; index++) {
		await vscode.commands.executeCommand("workbench.action.unlockEditorGroup");
		await vscode.commands.executeCommand("workbench.action.focusNextGroup");
	}

	const terminals = vscode.window.terminals.slice();

	for (const terminal of terminals) {
		terminal.dispose();
	}

	await until(
		async () => (await liveTerminals()).length === 0,
		"cleanup shell processes",
	);
	await until(
		() =>
			!vscode.window.tabGroups.all.some((g) =>
				g.tabs.some((t) => t.input instanceof vscode.TabInputTerminal),
			),
		"cleanup terminal tabs",
	);
	await vscode.commands.executeCommand("workbench.action.closeAllEditors");
	await vscode.commands.executeCommand("workbench.action.editorLayoutSingle");
	await until(() => vscode.window.tabGroups.all.length === 1, "reset groups");

	const documents: vscode.TextDocument[] = [];
	const root = vscode.workspace.workspaceFolders![0].uri;

	for (let column = 1; column <= groups; column++) {
		const uri = vscode.Uri.joinPath(root, `fixture-${column}.txt`);

		await vscode.workspace.fs.writeFile(
			uri,
			Buffer.from(`Fixture ${column}\n`),
		);
		documents.push(await vscode.workspace.openTextDocument(uri));
	}

	await code(1);
	await vscode.commands.executeCommand(
		`workbench.action.editorLayout${layout}`,
	);
	await until(
		() => vscode.window.tabGroups.all.length === groups,
		"requested layout",
	);

	for (let column = 1; column <= groups; column++) {
		await code(column);
	}

	// Every scenario starts from a normal layout and a false tracked value.
	// Use the public command so tests do not reach into extension storage.
	await vscode.commands.executeCommand(
		COMMANDS.workbench.toggleMaximizeEditorGroup,
		commandInput(false),
	);

	if (groups > 1) {
		await vscode.commands.executeCommand(
			COMMANDS.workbench.toggleMaximizeEditorGroup,
			commandInput(true),
		);
	}

	const other = vscode.window.createTerminal({ name: "Other Shell" });

	await other.processId;

	return { other, code, groups, assertFiles };

	async function code(column: number) {
		await vscode.window.showTextDocument(documents[column - 1], {
			viewColumn: column,
			preview: false,
		});
		await vscode.commands.executeCommand(
			"workbench.action.focusActiveEditorGroup",
		);
		await until(
			() =>
				vscode.window.tabGroups.activeTabGroup.viewColumn === column &&
				vscode.window.activeTextEditor?.document === documents[column - 1],
			"code editor starting state",
		);
	}
	function assertFiles() {
		assert.equal(
			vscode.window.tabGroups.all.length,
			groups,
			"no groups added or removed",
		);

		for (let column = 1; column <= groups; column++) {
			const tabs = vscode.window.tabGroups.all.find(
				(g) => g.viewColumn === column,
			)!.tabs;

			assert.ok(
				tabs.some(
					(t) =>
						t.input instanceof vscode.TabInputText &&
						t.input.uri.toString() === documents[column - 1].uri.toString(),
				),
				`fixture remains in group ${column}`,
			);
			assert.equal(
				documents[column - 1].isDirty,
				false,
				"terminal input must not modify a code file",
			);
		}
	}
}

function ownedTab(terminal: vscode.Terminal) {
	return vscode.window.tabGroups.all
		.flatMap((g) => g.tabs)
		.find(
			(t) =>
				t.input instanceof vscode.TabInputTerminal && t.label === terminal.name,
		);
}
function assertTerminal(terminal: vscode.Terminal) {
	assert.ok(terminal);

	const group = vscode.window.tabGroups.activeTabGroup;

	assert.equal(group.viewColumn, 1);
	assert.equal(vscode.window.activeTerminal, terminal);
	assert.equal(group.activeTab, ownedTab(terminal));
	assert.equal(group.tabs[0], group.activeTab);
	assert.equal(group.activeTab?.isPinned, true);
}
export function snapshot() {
	return vscode.window.tabGroups.all.flatMap((g) =>
		g.tabs.map((t) => ({
			column: g.viewColumn,
			name: t.label,
			pinned: t.isPinned,
		})),
	);
}
export async function until(
	check: () => boolean | Promise<boolean>,
	reason: string,
	timeout = 5000,
) {
	const deadline = Date.now() + timeout;

	while (!(await check())) {
		assert.ok(Date.now() < deadline, `Timed out: ${reason}`);
		await new Promise((resolve) => setTimeout(resolve, 20));
	}
}

// Some closed shells remain in the API list. Check their OS processes too,
// independently of the production service, before accepting fixture cleanup.
export async function terminalProcesses() {
	return Promise.all(
		vscode.window.terminals.map(async (terminal) => {
			const pid = await terminal.processId;

			assert.ok(pid, "test shell must have a process ID");

			let alive = true;

			try {
				process.kill(pid, 0);
			} catch (error) {
				if ((error as NodeJS.ErrnoException).code !== "ESRCH") {
					throw error;
				}

				alive = false;
			}

			return { terminal, pid, alive };
		}),
	);
}
async function liveTerminals() {
	return (await terminalProcesses())
		.filter((entry) => entry.alive)
		.map((entry) => entry.terminal);
}
