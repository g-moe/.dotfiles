import * as vscode from "vscode";

// Keep the workbench operations in order: each one acts on the active editor.
export async function focusTerminalEditor(
	terminal: vscode.Terminal,
	maximize: boolean,
	signal: AbortSignal,
) {
	const editor = new TerminalEditor(terminal, signal);

	await editor.reveal();
	await editor.moveToFirstGroup();
	await editor.pinFirstTab();

	if (maximize) {
		await editor.maximize();
	}

	assertActiveTerminal(terminal, signal);
}

class TerminalEditor {
	constructor(
		private readonly terminal: vscode.Terminal,
		private readonly signal: AbortSignal,
	) {}

	async reveal(): Promise<void> {
		const { terminal, signal } = this;

		signal.throwIfAborted();

		const editorGroup = vscode.window.tabGroups.all.find((group) =>
			group.tabs.some(
				(tab) =>
					tab.input instanceof vscode.TabInputTerminal &&
					tab.label === terminal.name,
			),
		);

		await this.selectGroup(editorGroup);

		// show() returns void. Wait for the public API state before the next command.
		terminal.show();
		await this.waitUntil(() => vscode.window.activeTerminal === terminal);

		// A terminal in the panel must move into the editor before tab operations.
		if (!editorGroup) {
			await vscode.commands.executeCommand("workbench.action.terminal.focus");
			assertActiveTerminal(terminal, signal, false);
			await vscode.commands.executeCommand(
				"workbench.action.terminal.moveToEditor",
			);
		}

		await this.waitUntil(() => activeTerminalTab(terminal) !== undefined);
		terminal.show();
		await this.waitUntil(() => vscode.window.activeTerminal === terminal);
	}

	private async selectGroup(
		editorGroup: vscode.TabGroup | undefined,
	): Promise<void> {
		const { signal } = this;

		// Terminal.show() can reveal a tab without selecting its editor group.
		// Select that group before using commands that act on the active tab.
		if (editorGroup && !editorGroup.isActive) {
			await vscode.commands.executeCommand(
				"workbench.action.focusFirstEditorGroup",
			);
			await this.waitUntil(
				() => vscode.window.tabGroups.activeTabGroup.viewColumn === 1,
			);

			for (let column = 2; column <= editorGroup.viewColumn; column++) {
				signal.throwIfAborted();
				await vscode.commands.executeCommand("workbench.action.focusNextGroup");
				await this.waitUntil(
					() => vscode.window.tabGroups.activeTabGroup.viewColumn === column,
				);
			}
		}
	}

	async moveToFirstGroup(): Promise<void> {
		const { terminal, signal } = this;

		// Clear any multiple-tab selection so only the terminal moves to group 1.
		const tab = activeTerminalTab(terminal)!;

		await vscode.commands.executeCommand(
			"workbench.action.openEditorAtIndex",
			tab.group.tabs.indexOf(tab),
		);
		assertActiveTerminal(terminal, signal);
		await vscode.commands.executeCommand("moveActiveEditor", {
			to: "first",
			by: "group",
		});
		await this.waitUntil(
			() =>
				activeTerminalTab(terminal)?.group.viewColumn === vscode.ViewColumn.One,
		);

		// Moving a tab can change terminal focus. Restore it before pinning.
		terminal.show();
		await this.waitUntil(() => vscode.window.activeTerminal === terminal);
		assertActiveTerminal(terminal, signal);
	}

	async pinFirstTab(): Promise<void> {
		const { terminal, signal } = this;

		// VS Code calls a sticky tab "pinned". Pin first, then place it before other pins.
		await vscode.commands.executeCommand("workbench.action.pinEditor");
		assertActiveTerminal(terminal, signal);
		await vscode.commands.executeCommand("moveActiveEditor", {
			to: "first",
			by: "tab",
		});
		await this.waitUntil(() => {
			const tab = activeTerminalTab(terminal);

			return (
				vscode.window.activeTerminal === terminal &&
				tab?.group.viewColumn === vscode.ViewColumn.One &&
				tab?.isPinned === true &&
				tab.group.tabs[0] === tab
			);
		});
	}

	async maximize(): Promise<void> {
		const { terminal, signal } = this;

		// Focusing another group exits an existing maximized layout and restores its
		// sizes. Return to group 1 before toggling so repeated calls stay maximized.
		// Unlike maximizeEditorHideSidebar, these commands preserve both sidebars.
		if (vscode.window.tabGroups.all.length > 1) {
			assertActiveTerminal(terminal, signal);
			await vscode.commands.executeCommand("runCommands", {
				commands: [
					"workbench.action.focusLastEditorGroup",
					"workbench.action.focusFirstEditorGroup",
					"workbench.action.toggleMaximizeEditorGroup",
				],
			});
		}

		assertActiveTerminal(terminal, signal);
	}

	// Tab events arrive after the commands complete. Bound every state wait and
	// stop immediately if the terminal closes or the extension is disposed.
	private async waitUntil(check: () => boolean): Promise<void> {
		const { terminal, signal } = this;
		const deadline = Date.now() + 5000;

		while (!check()) {
			signal.throwIfAborted();

			if (
				terminal.exitStatus !== undefined ||
				!vscode.window.terminals.includes(terminal)
			) {
				throw new Error("The terminal closed. Run the command again.");
			}

			if (Date.now() >= deadline) {
				throw new Error(
					"VS Code did not finish opening or moving the terminal.",
				);
			}

			await new Promise((resolve) => setTimeout(resolve, 20));
		}
	}
}

function activeTerminalTab(terminal: vscode.Terminal) {
	const tab = vscode.window.tabGroups.activeTabGroup.activeTab;

	return tab?.input instanceof vscode.TabInputTerminal &&
		tab.label === terminal.name
		? tab
		: undefined;
}

function assertActiveTerminal(
	terminal: vscode.Terminal,
	signal: AbortSignal,
	editorRequired = true,
) {
	signal.throwIfAborted();

	if (
		vscode.window.activeTerminal !== terminal ||
		terminal.exitStatus !== undefined ||
		(editorRequired && !activeTerminalTab(terminal))
	) {
		throw new Error(
			"The terminal changed or closed. Run Focus Terminal again.",
		);
	}
}
