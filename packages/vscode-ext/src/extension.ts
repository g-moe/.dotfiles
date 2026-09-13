import * as vscode from "vscode";

import { registerBetterErrors } from "./features/errors";
import { registerBetterTerminal } from "./features/terminal";

export function activate(context: vscode.ExtensionContext) {
	registerBetterErrors(context);
	registerBetterTerminal(context);
}
