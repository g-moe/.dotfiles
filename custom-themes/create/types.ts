export type Mode = "dark" | "light";

export type Variant = {
	background: string;
	backgroundPanel: string;
	backgroundElement: string;
	foreground: string;
	foregroundMuted: string;
	border: string;
	borderActive: string;
	primary: string;
	secondary: string;
	accent: string;
	error: string;
	warning: string;
	success: string;
	info: string;
	selectionBackground: string;
	selectionForeground: string;
	cursor: string;
	syntax: {
		comment: string;
		keyword: string;
		function: string;
		method: string;
		string: string;
		number: string;
		type: string;
		variable: string;
		operator: string;
		punctuation: string;
	};
};

export type TerminalAnsi = {
	black: string;
	red: string;
	green: string;
	yellow: string;
	blue: string;
	magenta: string;
	cyan: string;
	white: string;
	brightBlack: string;
	brightRed: string;
	brightGreen: string;
	brightYellow: string;
	brightBlue: string;
	brightMagenta: string;
	brightCyan: string;
	brightWhite: string;
};

export type ThemeTokens = {
	name: string;
	displayName: string;
	variants: Record<Mode, Variant>;
};

export type CreateInstallModule = {
	appName: string;
	create: (tokens: ThemeTokens) => Promise<string[]>;
	install: () => Promise<string[]>;
};
