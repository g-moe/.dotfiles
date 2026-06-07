import { PATHS } from "../paths";
import type { CreateInstallModule, ThemeTokens } from "../types";
import { installFile, writeJson } from "../utils";

function buildOpenCodeTheme(tokens: ThemeTokens) {
	const dark = tokens.variants.dark;
	const light = tokens.variants.light;

	return {
		$schema: "https://opencode.ai/theme.json",
		defs: {
			dark_bg: dark.background,
			dark_panel: dark.backgroundPanel,
			dark_element: dark.backgroundElement,
			dark_text: dark.foreground,
			dark_muted: dark.foregroundMuted,
			dark_border: dark.border,
			dark_border_active: dark.borderActive,
			dark_primary: dark.primary,
			dark_secondary: dark.secondary,
			dark_accent: dark.accent,
			dark_error: dark.error,
			dark_warning: dark.warning,
			dark_success: dark.success,
			dark_info: dark.info,
			dark_comment: dark.syntax.comment,
			dark_keyword: dark.syntax.keyword,
			dark_function: dark.syntax.function,
			dark_variable: dark.syntax.variable,
			dark_string: dark.syntax.string,
			dark_number: dark.syntax.number,
			dark_type: dark.syntax.type,
			dark_operator: dark.syntax.operator,
			dark_punctuation: dark.syntax.punctuation,
			light_bg: light.background,
			light_panel: light.backgroundPanel,
			light_element: light.backgroundElement,
			light_text: light.foreground,
			light_muted: light.foregroundMuted,
			light_border: light.border,
			light_border_active: light.borderActive,
			light_primary: light.primary,
			light_secondary: light.secondary,
			light_accent: light.accent,
			light_error: light.error,
			light_warning: light.warning,
			light_success: light.success,
			light_info: light.info,
			light_comment: light.syntax.comment,
			light_keyword: light.syntax.keyword,
			light_function: light.syntax.function,
			light_variable: light.syntax.variable,
			light_string: light.syntax.string,
			light_number: light.syntax.number,
			light_type: light.syntax.type,
			light_operator: light.syntax.operator,
			light_punctuation: light.syntax.punctuation,
		},
		theme: {
			primary: { dark: "dark_primary", light: "light_primary" },
			secondary: { dark: "dark_secondary", light: "light_secondary" },
			accent: { dark: "dark_accent", light: "light_accent" },
			error: { dark: "dark_error", light: "light_error" },
			warning: { dark: "dark_warning", light: "light_warning" },
			success: { dark: "dark_success", light: "light_success" },
			info: { dark: "dark_info", light: "light_info" },
			text: { dark: "dark_text", light: "light_text" },
			textMuted: { dark: "dark_muted", light: "light_muted" },
			background: { dark: "dark_bg", light: "light_bg" },
			backgroundPanel: { dark: "dark_panel", light: "light_panel" },
			backgroundElement: { dark: "dark_element", light: "light_element" },
			border: { dark: "dark_border", light: "light_border" },
			borderActive: {
				dark: "dark_border_active",
				light: "light_border_active",
			},
			borderSubtle: { dark: "dark_border", light: "light_border" },
			diffAdded: { dark: "dark_success", light: "light_success" },
			diffRemoved: { dark: "dark_error", light: "light_error" },
			diffContext: { dark: "dark_muted", light: "light_muted" },
			diffHunkHeader: { dark: "dark_info", light: "light_info" },
			diffHighlightAdded: { dark: "dark_success", light: "light_success" },
			diffHighlightRemoved: { dark: "dark_error", light: "light_error" },
			diffAddedBg: { dark: "dark_panel", light: "light_element" },
			diffRemovedBg: { dark: "dark_panel", light: "light_element" },
			diffContextBg: { dark: "dark_bg", light: "light_bg" },
			diffLineNumber: { dark: "dark_muted", light: "light_muted" },
			diffAddedLineNumberBg: { dark: "dark_panel", light: "light_element" },
			diffRemovedLineNumberBg: { dark: "dark_panel", light: "light_element" },
			markdownText: { dark: "dark_text", light: "light_text" },
			markdownHeading: { dark: "dark_accent", light: "light_accent" },
			markdownLink: { dark: "dark_primary", light: "light_primary" },
			markdownLinkText: { dark: "dark_secondary", light: "light_secondary" },
			markdownCode: { dark: "dark_string", light: "light_string" },
			markdownBlockQuote: { dark: "dark_muted", light: "light_muted" },
			markdownEmph: { dark: "dark_warning", light: "light_warning" },
			markdownStrong: { dark: "dark_accent", light: "light_accent" },
			markdownHorizontalRule: { dark: "dark_border", light: "light_border" },
			markdownListItem: { dark: "dark_primary", light: "light_primary" },
			markdownListEnumeration: { dark: "dark_info", light: "light_info" },
			markdownImage: { dark: "dark_primary", light: "light_primary" },
			markdownImageText: { dark: "dark_secondary", light: "light_secondary" },
			markdownCodeBlock: { dark: "dark_text", light: "light_text" },
			syntaxComment: { dark: "dark_comment", light: "light_comment" },
			syntaxKeyword: { dark: "dark_keyword", light: "light_keyword" },
			syntaxFunction: { dark: "dark_function", light: "light_function" },
			syntaxVariable: { dark: "dark_variable", light: "light_variable" },
			syntaxString: { dark: "dark_string", light: "light_string" },
			syntaxNumber: { dark: "dark_number", light: "light_number" },
			syntaxType: { dark: "dark_type", light: "light_type" },
			syntaxOperator: { dark: "dark_operator", light: "light_operator" },
			syntaxPunctuation: {
				dark: "dark_punctuation",
				light: "light_punctuation",
			},
		},
	};
}

export const opencodeApp: CreateInstallModule = {
	appName: "opencode",
	async create(tokens: ThemeTokens) {
		const theme = buildOpenCodeTheme(tokens);
		await writeJson(PATHS.output.opencode.theme, theme);
		return [PATHS.output.opencode.theme];
	},
	async install() {
		await installFile(
			PATHS.output.opencode.theme,
			PATHS.install.opencode.theme,
		);
		return [PATHS.install.opencode.theme];
	},
};
