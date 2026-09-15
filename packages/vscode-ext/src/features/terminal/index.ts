import * as vscode from "vscode";

import { COMMANDS } from "../../commands";
import {
	readCurrentMaximized,
	type WorkbenchEditor,
} from "../../shared/workbench/editor";
import { TERMINAL_STATE_KEY } from "./constants";
import { focusTerminalEditor } from "./editor";
import { TerminalService } from "./service";
import { readProcessStart, isProcessAlive } from "./process";
import type { TerminalState } from "./contracts";

export function registerBetterTerminal(
	context: vscode.ExtensionContext,
	editor: WorkbenchEditor,
) {
	const service = new TerminalService({
		terminals: () => vscode.window.terminals,
		create: (options) => vscode.window.createTerminal(options),
		onClose: vscode.window.onDidCloseTerminal,
		load: () => context.workspaceState.get<TerminalState>(TERMINAL_STATE_KEY),
		save: (state) => context.workspaceState.update(TERMINAL_STATE_KEY, state),
		processStart: readProcessStart,
		processAlive: isProcessAlive,
	});

	context.subscriptions.push(service);
	context.subscriptions.push(
		vscode.commands.registerCommand(COMMANDS.terminal.focus, (input: unknown) =>
			editor.run(async () => {
				const snapshot = await editor.capture(readCurrentMaximized(input));
				const terminal = await service.getTerminal();

				await focusTerminalEditor(terminal, editor, snapshot, service.signal);
			}),
		),
	);
}
