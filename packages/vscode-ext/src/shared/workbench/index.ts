import * as vscode from "vscode";

import { COMMANDS } from "../../commands";
import {
	readCurrentMaximized,
	TrackedWorkbenchEditor,
	type WorkbenchEditor,
} from "./editor";

export interface Workbench {
	editor: WorkbenchEditor;
}

export function registerWorkbench(context: vscode.ExtensionContext): Workbench {
	const editor = new TrackedWorkbenchEditor(context);

	context.subscriptions.push(
		editor,
		vscode.commands.registerCommand(
			COMMANDS.workbench.toggleMaximizeEditorGroup,
			(input: unknown) =>
				editor.run(() =>
					editor.toggleMaximizeGroup(readCurrentMaximized(input)),
				),
		),
	);

	return { editor };
}
