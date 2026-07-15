export type BetterErrorPosition = {
	line: number;
	character: number;
};

export type BetterErrorRange = {
	start: BetterErrorPosition;
	end: BetterErrorPosition;
};

export type BetterErrorSeverity =
	| "error"
	| "warning"
	| "information"
	| "hint"
	| "unknown";

export type BetterErrorRelatedInformation = {
	filePath: string;
	range: BetterErrorRange;
	message: string;
};

export type BetterErrorCodeSnippet = {
	filePath: string;
	range: BetterErrorRange;
	languageId: string;
	text: string;
};

export type BetterErrorReference = {
	filePath: string;
	range: BetterErrorRange;
	snippet: string;
};

export type BetterErrorCallHierarchyItem = {
	name: string;
	filePath: string;
	range: BetterErrorRange;
};

export type BetterErrorCallHierarchy = {
	incoming: readonly BetterErrorCallHierarchyItem[];
	outgoing: readonly BetterErrorCallHierarchyItem[];
};

export type BetterErrorPrimarySymbol = {
	name: string;
	selectedExpression: string;
	hoverText?: string;
	definition?: BetterErrorCodeSnippet;
	typeDefinition?: BetterErrorCodeSnippet;
};

export type BetterErrorDiagnostic = {
	filePath: string;
	documentLanguageId: string;
	range: BetterErrorRange;
	selection: BetterErrorRange;
	severity: BetterErrorSeverity;
	message: string;
	rawMessage: string;
	source?: string;
	code?: string;
	relatedInformation: readonly BetterErrorRelatedInformation[];
	contextText: string;
	activeScope?: BetterErrorCodeSnippet;
	definition?: BetterErrorCodeSnippet;
	typeDefinition?: BetterErrorCodeSnippet;
	references: readonly BetterErrorReference[];
	callHierarchy?: BetterErrorCallHierarchy;
};

export type BetterErrorPromptInput = {
	diagnostic: BetterErrorDiagnostic;
};
