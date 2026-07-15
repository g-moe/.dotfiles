import * as vscode from "vscode";

import { registerBetterErrors } from "./better-errors";

export function activate(context: vscode.ExtensionContext) {
	registerBetterErrors(context);
}

export function deactivate() {}
