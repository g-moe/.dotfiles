export const BETTER_ERRORS_COMMAND_PREFIX = "betterErrors";
export const BETTER_ERRORS_DISPLAY_PREFIX = "better-errors";

export const BETTER_ERRORS_COMMANDS = {
	copyError: `${BETTER_ERRORS_COMMAND_PREFIX}.copyError`,
	toggleEnabled: `${BETTER_ERRORS_COMMAND_PREFIX}.toggleEnabled`,
} as const;

export const BETTER_ERRORS_COMMAND_TITLES = {
	copyError: `${BETTER_ERRORS_DISPLAY_PREFIX}: Copy Error`,
	toggleEnabled: `${BETTER_ERRORS_DISPLAY_PREFIX}: Toggle Enabled`,
} as const;

export const BETTER_ERRORS_CONFIG = {
	root: "betterErrors",
	enabled: "enabled",
	includeWorkspaceRelativePath: "includeWorkspaceRelativePath",
	includeSelection: "includeSelection",
	contextLineCount: "contextLineCount",
} as const;

export const BETTER_ERRORS_PROMPT_DEFAULTS = {
	instruction:
		"You are investigating a real editor error in a codebase. Use the diagnostic and project evidence below to find the most likely root cause. Prefer project-specific evidence over generic advice.",
	emptyContextPlaceholder: "<no local context>",
	emptyActiveScopePlaceholder: "<no enclosing scope found>",
	emptyDefinitionPlaceholder: "<no definition found>",
	emptyTypeDefinitionPlaceholder: "<no type definition found>",
	emptyRelatedDiagnosticsPlaceholder: "<no related diagnostics>",
	emptyReferencesPlaceholder: "<no references found>",
	emptyCallHierarchyPlaceholder: "<no call hierarchy available>",
} as const;
