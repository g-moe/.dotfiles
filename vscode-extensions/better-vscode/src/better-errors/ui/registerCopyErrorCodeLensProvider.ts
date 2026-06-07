import * as vscode from "vscode";

import {
	BETTER_ERRORS_COMMANDS,
	BETTER_ERRORS_COMMAND_TITLES,
	BETTER_ERRORS_CONFIG,
} from "../../shared/consts/betterErrors";
import { selectCodeLensDiagnostics } from "../diagnostics/selectCodeLensDiagnostics";

export function registerCopyErrorCodeLensProvider(): vscode.Disposable {
	const onDidChangeCodeLenses = new vscode.EventEmitter<void>();

	const provider = vscode.languages.registerCodeLensProvider(
		[{ scheme: "file" }, { scheme: "untitled" }],
		{
			onDidChangeCodeLenses: onDidChangeCodeLenses.event,
			provideCodeLenses(document) {
				if (!isBetterErrorsEnabled()) {
					return [];
				}

				const diagnostics = selectCodeLensDiagnostics(
					vscode.languages.getDiagnostics(document.uri).map((diagnostic) => ({
						diagnostic,
						range: {
							start: {
								line: diagnostic.range.start.line,
								character: diagnostic.range.start.character,
							},
							end: {
								line: diagnostic.range.end.line,
								character: diagnostic.range.end.character,
							},
						},
						severity: formatSeverity(diagnostic.severity),
					})),
				);

				return diagnostics.map(
					(diagnostic) =>
						new vscode.CodeLens(diagnostic.range, {
							command: BETTER_ERRORS_COMMANDS.copyError,
							title: BETTER_ERRORS_COMMAND_TITLES.copyError,
							arguments: [document.uri, diagnostic.range],
						}),
				);
			},
		},
	);

	const diagnosticsSubscription = vscode.languages.onDidChangeDiagnostics(
		() => {
			onDidChangeCodeLenses.fire();
		},
	);

	const configurationSubscription = vscode.workspace.onDidChangeConfiguration(
		(event) => {
			if (
				event.affectsConfiguration(
					`${BETTER_ERRORS_CONFIG.root}.${BETTER_ERRORS_CONFIG.enabled}`,
				)
			) {
				onDidChangeCodeLenses.fire();
			}
		},
	);

	return vscode.Disposable.from(
		provider,
		diagnosticsSubscription,
		configurationSubscription,
		onDidChangeCodeLenses,
	);
}

function isBetterErrorsEnabled(): boolean {
	return vscode.workspace
		.getConfiguration(BETTER_ERRORS_CONFIG.root)
		.get(BETTER_ERRORS_CONFIG.enabled, true);
}

function formatSeverity(
	severity: vscode.DiagnosticSeverity,
): "error" | "warning" | "information" | "hint" | "unknown" {
	switch (severity) {
		case vscode.DiagnosticSeverity.Error:
			return "error";
		case vscode.DiagnosticSeverity.Warning:
			return "warning";
		case vscode.DiagnosticSeverity.Information:
			return "information";
		case vscode.DiagnosticSeverity.Hint:
			return "hint";
		default:
			return "unknown";
	}
}
