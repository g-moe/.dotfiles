export const COMMANDS = {
	errors: {
		copyError: "betterErrors.copyError",
		toggleEnabled: "betterErrors.toggleEnabled",
	},
	terminal: {
		focus: "better-vscode.terminal.focus",
	},
	workbench: {
		toggleMaximizeEditorGroup:
			"better-vscode.workbench.toggleMaximizeEditorGroup",
	},
} as const;

export const COMMAND_TITLES = {
	errors: {
		copyError: "better-errors: Copy Error",
		toggleEnabled: "better-errors: Toggle Enabled",
	},
} as const;
