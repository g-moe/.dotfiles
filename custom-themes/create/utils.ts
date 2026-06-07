import { copyFile, mkdir, readFile, writeFile } from "fs/promises";
import path from "path";
import { parse } from "jsonc-parser";
import type { TerminalAnsi, ThemeTokens, Variant } from "./types";

export async function readJsonc<T>(filePath: string): Promise<T> {
	const content = await readFile(filePath, "utf8");
	return parse(content) as T;
}

function kebabToCamel(str: string): string {
	return str.replace(/-([a-z])/g, (_, c) => c.toUpperCase());
}

function parseCssBlock(css: string): Record<string, string> {
	const props: Record<string, string> = {};
	const regex = /--([\w-]+):\s*([^;]+);/g;
	let match: RegExpExecArray | null;
	while ((match = regex.exec(css)) !== null) {
		const key = kebabToCamel(match[1]);
		const value = match[2].trim().replace(/^["']|["']$/g, "");
		props[key] = value;
	}
	return props;
}

function propsToVariant(props: Record<string, string>): Variant {
	return {
		background: props.background,
		backgroundPanel: props.backgroundPanel,
		backgroundElement: props.backgroundElement,
		foreground: props.foreground,
		foregroundMuted: props.foregroundMuted,
		border: props.border,
		borderActive: props.borderActive,
		primary: props.primary,
		secondary: props.secondary,
		accent: props.accent,
		error: props.error,
		warning: props.warning,
		success: props.success,
		info: props.info,
		selectionBackground: props.selectionBackground,
		selectionForeground: props.selectionForeground,
		cursor: props.cursor,
		syntax: {
			comment: props.syntaxComment,
			keyword: props.syntaxKeyword,
			function: props.syntaxFunction,
			method: props.syntaxMethod,
			string: props.syntaxString,
			number: props.syntaxNumber,
			type: props.syntaxType,
			variable: props.syntaxVariable,
			operator: props.syntaxOperator,
			punctuation: props.syntaxPunctuation,
		},
	};
}

export async function parseCssTokens(filePath: string): Promise<ThemeTokens> {
	const content = await readFile(filePath, "utf8");

	const rootMatch = content.match(/:root\s*\{([^}]+)\}/);
	const rootProps = rootMatch ? parseCssBlock(rootMatch[1]) : {};

	const darkMatch = content.match(/:root\[data-theme="dark"\]\s*\{([^}]+)\}/);
	const lightMatch = content.match(/:root\[data-theme="light"\]\s*\{([^}]+)\}/);

	const darkProps = darkMatch ? parseCssBlock(darkMatch[1]) : {};
	const lightProps = lightMatch ? parseCssBlock(lightMatch[1]) : {};

	return {
		name: rootProps.name || "gtheme",
		displayName: rootProps.displayName || "gtheme",
		variants: {
			dark: propsToVariant(darkProps),
			light: propsToVariant(lightProps),
		},
	};
}

export async function writeJson(
	filePath: string,
	value: unknown,
): Promise<void> {
	await mkdir(path.dirname(filePath), { recursive: true });
	await writeFile(filePath, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

export async function writeText(
	filePath: string,
	value: string,
): Promise<void> {
	await mkdir(path.dirname(filePath), { recursive: true });
	await writeFile(filePath, value, "utf8");
}

export async function installFile(
	sourcePath: string,
	destinationPath: string,
): Promise<void> {
	await mkdir(path.dirname(destinationPath), { recursive: true });
	await copyFile(sourcePath, destinationPath);
}

export function deriveTerminalAnsi(variant: Variant): TerminalAnsi {
	return {
		black: variant.background,
		red: variant.syntax.keyword,
		green: variant.syntax.string,
		yellow: variant.syntax.type,
		blue: variant.syntax.variable,
		magenta: variant.syntax.number,
		cyan: variant.info,
		white: variant.syntax.punctuation,
		brightBlack: variant.syntax.comment,
		brightRed: variant.syntax.keyword,
		brightGreen: variant.syntax.string,
		brightYellow: variant.syntax.type,
		brightBlue: variant.syntax.variable,
		brightMagenta: variant.syntax.number,
		brightCyan: variant.info,
		brightWhite: variant.foreground,
	};
}
