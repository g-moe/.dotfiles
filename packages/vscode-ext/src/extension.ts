import * as vscode from "vscode";

import { registerBetterErrors } from "./features/errors";
import { registerBetterTerminal } from "./features/terminal";
import { registerWorkbench } from "./shared/workbench";

export function activate(context: vscode.ExtensionContext) {
	const workbench = registerWorkbench(context);

	registerBetterErrors(context);
	registerBetterTerminal(context, workbench.editor);
}
