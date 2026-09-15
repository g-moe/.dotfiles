import * as vscode from "vscode";

const MAXIMIZED_GROUP_STATE_KEY =
	"better-vscode.workbench.editorGroupMaximized";

export interface EditorSnapshot {
	maximizedGroup: boolean;
}

export interface WorkbenchEditor extends vscode.Disposable {
	capture(currentMaximized?: boolean): Promise<EditorSnapshot>;
	isGroupMaximized(): boolean;
	restore(snapshot: EditorSnapshot): Promise<void>;
	run<R>(operation: () => Promise<R>): Promise<R>;
	toggleMaximizeGroup(currentMaximized?: boolean): Promise<void>;
	readonly onDidChangeMaximizedGroup: vscode.Event<boolean>;
}

export class TrackedWorkbenchEditor implements WorkbenchEditor {
	private maximizedGroup: boolean;
	private pending = Promise.resolve();
	private readonly changed = new vscode.EventEmitter<boolean>();

	readonly onDidChangeMaximizedGroup = this.changed.event;

	constructor(private readonly context: vscode.ExtensionContext) {
		this.maximizedGroup =
			context.workspaceState.get<boolean>(MAXIMIZED_GROUP_STATE_KEY) ?? false;
	}

	async capture(currentMaximized?: boolean): Promise<EditorSnapshot> {
		if (currentMaximized !== undefined) {
			await this.setMaximizedGroup(currentMaximized);
		}

		return { maximizedGroup: this.maximizedGroup };
	}

	isGroupMaximized(): boolean {
		return this.maximizedGroup;
	}

	async restore(snapshot: EditorSnapshot): Promise<void> {
		if (!snapshot.maximizedGroup || vscode.window.tabGroups.all.length < 2) {
			await this.setMaximizedGroup(false);

			return;
		}

		// Selecting another group exits maximized mode. Return to group 1 and
		// maximize it from a known normal layout.
		await vscode.commands.executeCommand(
			"workbench.action.focusLastEditorGroup",
		);
		await vscode.commands.executeCommand(
			"workbench.action.focusFirstEditorGroup",
		);
		await vscode.commands.executeCommand(
			"workbench.action.toggleMaximizeEditorGroup",
		);
		await this.setMaximizedGroup(true);
	}

	run<R>(operation: () => Promise<R>): Promise<R> {
		const current = this.pending.then(operation);

		// Keep later operations available after a rejected command.
		this.pending = current.then(
			() => undefined,
			() => undefined,
		);

		return current;
	}

	async toggleMaximizeGroup(currentMaximized?: boolean): Promise<void> {
		const snapshot = await this.capture(currentMaximized);

		if (vscode.window.tabGroups.all.length < 2) {
			await this.setMaximizedGroup(false);

			return;
		}

		await vscode.commands.executeCommand(
			"workbench.action.toggleMaximizeEditorGroup",
		);
		await this.setMaximizedGroup(!snapshot.maximizedGroup);
	}

	dispose(): void {
		this.changed.dispose();
	}

	private async setMaximizedGroup(maximized: boolean): Promise<void> {
		if (this.maximizedGroup === maximized) {
			return;
		}

		this.maximizedGroup = maximized;
		await this.context.workspaceState.update(
			MAXIMIZED_GROUP_STATE_KEY,
			maximized,
		);
		this.changed.fire(maximized);
	}
}

export function readCurrentMaximized(input: unknown): boolean | undefined {
	if (input === undefined) {
		return undefined;
	}

	if (
		typeof input === "object" &&
		input !== null &&
		"currentMaximized" in input &&
		typeof input.currentMaximized === "boolean"
	) {
		return input.currentMaximized;
	}

	throw new Error("The editor maximize command received invalid state.");
}
