import { PATHS } from "../paths";
import type { CreateInstallModule, ThemeTokens, Variant } from "../types";
import {
	deriveTerminalAnsi,
	installFile,
	readJsonc,
	writeJson,
} from "../utils";

function updateVscodeTheme(theme: any, variant: Variant, modeLabel: string) {
	const output = JSON.parse(JSON.stringify(theme));
	output.name = modeLabel;
	output.colors = output.colors || {};
	const terminalAnsi = deriveTerminalAnsi(variant);

	const blueHighlight = `${terminalAnsi.blue}14`;
	const blueHighlightStrong = `${terminalAnsi.blue}1F`;
	const blueHighlightSoft = `${terminalAnsi.blue}10`;
	const blueHighlightBorder = `${terminalAnsi.blue}38`;
	const transparent = `${variant.background}00`;
	const unfocusedTopBorder = `${variant.foregroundMuted}80`;
	const backgroundSemiTransparent = `${variant.background}d7`;
	const borderSubtle = `${variant.border}66`;

	// Core backgrounds
	output.colors["editor.background"] = variant.background;
	output.colors["editor.foreground"] = variant.foreground;
	output.colors["editorCursor.foreground"] = variant.cursor;

	// Sidebar, activity bar, panels
	output.colors["sideBar.background"] = variant.background;
	output.colors["sideBar.foreground"] = variant.foregroundMuted;
	output.colors["sideBar.border"] = borderSubtle;
	output.colors["sideBarTitle.foreground"] = variant.foreground;
	output.colors["sideBarSectionHeader.background"] = variant.background;
	output.colors["sideBarSectionHeader.foreground"] = variant.foreground;
	output.colors["activityBar.background"] = variant.background;
	output.colors["activityBar.foreground"] = variant.foreground;
	output.colors["activityBar.border"] = variant.background;
	output.colors["activityBarBadge.background"] = `${variant.info}b4`;
	output.colors["activityBarBadge.foreground"] = variant.foreground;

	// Title bar
	output.colors["titleBar.activeBackground"] = variant.background;
	output.colors["titleBar.activeForeground"] = variant.foreground;
	output.colors["titleBar.inactiveBackground"] = variant.background;
	output.colors["titleBar.border"] = borderSubtle;

	// Status bar
	output.colors["statusBar.background"] = variant.background;
	output.colors["statusBar.foreground"] = variant.foreground;
	output.colors["statusBar.border"] = borderSubtle;
	output.colors["statusBar.noFolderBackground"] = variant.background;
	output.colors["statusBar.noFolderBorder"] = transparent;
	output.colors["statusBar.debuggingForeground"] = variant.background;
	output.colors["statusBar.debuggingBorder"] = transparent;

	// Panel (terminal, output, etc.)
	output.colors["panel.background"] = variant.background;
	output.colors["panel.border"] = borderSubtle;
	output.colors["panelTitle.activeForeground"] = variant.foreground;
	output.colors["panelSectionHeader.background"] = variant.background;

	// Command center
	output.colors["commandCenter.background"] = variant.background;

	// Widgets and hover
	output.colors["editorWidget.background"] = variant.background;
	output.colors["editorWidget.border"] = variant.background;
	output.colors["editorHoverWidget.background"] = variant.background;
	output.colors["editorHoverWidget.border"] = variant.backgroundPanel;
	output.colors["editorSuggestWidget.background"] = variant.background;
	output.colors["editorSuggestWidget.foreground"] = variant.foreground;
	output.colors["editorSuggestWidget.border"] = variant.backgroundPanel;
	output.colors["editorSuggestWidget.selectedBackground"] =
		`${variant.selectionBackground}40`;

	// Peek view
	output.colors["peekView.border"] = variant.backgroundPanel;
	output.colors["peekViewEditor.background"] = variant.background;
	output.colors["peekViewEditorGutter.background"] = variant.background;
	output.colors["peekViewEditor.matchHighlightBackground"] =
		variant.backgroundPanel;
	output.colors["peekViewResult.background"] = variant.background;
	output.colors["peekViewResult.fileForeground"] = variant.foreground;
	output.colors["peekViewResult.selectionBackground"] =
		`${variant.selectionBackground}40`;
	output.colors["peekViewTitle.background"] = variant.background;
	output.colors["peekViewTitleDescription.foreground"] =
		variant.foregroundMuted;
	output.colors["peekViewTitleLabel.foreground"] = variant.foreground;

	// Buttons
	output.colors["button.background"] = variant.backgroundPanel;
	output.colors["button.foreground"] = variant.foreground;
	output.colors["button.hoverBackground"] = variant.foregroundMuted;
	output.colors["button.secondaryBackground"] = variant.background;
	output.colors["button.secondaryForeground"] = variant.foreground;
	output.colors["button.secondaryHoverBackground"] = variant.backgroundPanel;

	// Dropdowns and inputs
	output.colors["dropdown.background"] = variant.background;
	output.colors["dropdown.border"] = `${variant.border}4e`;
	output.colors["dropdown.foreground"] = variant.foreground;
	output.colors["input.background"] = `${variant.foreground}01`;
	output.colors["input.border"] = `${variant.border}4e`;
	output.colors["input.foreground"] = variant.foreground;
	output.colors["input.placeholderForeground"] = `${variant.foreground}60`;

	// Scrollbar
	output.colors["scrollbar.shadow"] = "#00000000";
	output.colors["scrollbarSlider.activeBackground"] =
		`${variant.foregroundMuted}99`;
	output.colors["scrollbarSlider.hoverBackground"] =
		`${variant.foregroundMuted}66`;
	output.colors["scrollbarSlider.background"] = `${variant.foregroundMuted}44`;

	// Badge
	output.colors["badge.background"] = variant.info;
	output.colors["badge.foreground"] = variant.background;

	// Lists
	output.colors["list.activeSelectionBackground"] =
		`${variant.selectionBackground}40`;
	output.colors["list.activeSelectionForeground"] = variant.foreground;
	output.colors["list.hoverBackground"] = `${variant.selectionBackground}1a`;
	output.colors["list.hoverForeground"] = variant.foreground;
	output.colors["list.focusBackground"] = `${variant.selectionBackground}40`;
	output.colors["list.focusForeground"] = variant.foreground;
	output.colors["list.focusOutline"] = `${variant.border}99`;
	output.colors["list.focusAndSelectionOutline"] = `${variant.border}66`;
	output.colors["list.inactiveFocusOutline"] = `${variant.foregroundMuted}66`;
	output.colors["list.inactiveSelectionForeground"] = variant.foreground;
	output.colors["list.inactiveSelectionBackground"] =
		`${variant.selectionBackground}26`;
	output.colors["list.dropBackground"] = variant.backgroundPanel;

	// Quick input (command palette)
	output.colors["quickInputList.focusBackground"] =
		`${variant.selectionBackground}40`;
	output.colors["quickInputList.focusForeground"] = variant.foreground;
	output.colors["list.highlightForeground"] = variant.syntax.string;

	// Tabs
	output.colors["tab.activeBackground"] = backgroundSemiTransparent;
	output.colors["tab.activeForeground"] = variant.foreground;
	output.colors["tab.inactiveForeground"] = `${variant.foregroundMuted}93`;
	output.colors["tab.inactiveBackground"] = backgroundSemiTransparent;
	output.colors["tab.unfocusedActiveBackground"] = backgroundSemiTransparent;
	output.colors["tab.unfocusedActiveForeground"] = variant.foreground;
	output.colors["tab.unfocusedInactiveForeground"] = variant.foregroundMuted;

	// Editor groups
	output.colors["editorGroup.border"] = borderSubtle;
	output.colors["editorGroup.dropBackground"] = variant.backgroundPanel;
	output.colors["editorGroupHeader.noTabsBackground"] = transparent;
	output.colors["editorGroupHeader.tabsBackground"] = transparent;

	// Editor misc
	output.colors["editorLineNumber.foreground"] = variant.foregroundMuted;
	output.colors["editorGutter.background"] = transparent;
	output.colors["editorOverviewRuler.border"] = transparent;
	output.colors["editorBracketMatch.border"] = transparent;
	output.colors["editor.lineHighlightBorder"] = transparent;

	// Debug toolbar
	output.colors["debugToolBar.background"] = variant.background;

	// Terminal border
	output.colors["terminal.border"] = borderSubtle;

	// Menu
	output.colors["menu.separatorBackground"] = variant.backgroundPanel;

	// Merge
	output.colors["merge.border"] = borderSubtle;

	// Foreground colors
	output.colors["foreground"] = variant.foreground;
	output.colors["descriptionForeground"] = variant.foregroundMuted;
	output.colors["disabledForeground"] = variant.foregroundMuted;
	output.colors["list.deemphasizedForeground"] = variant.foregroundMuted;

	// Selection and highlights
	output.colors["selection.background"] = blueHighlight;
	output.colors["editor.selectionBackground"] = blueHighlightStrong;
	output.colors["editor.inactiveSelectionBackground"] = blueHighlight;
	output.colors["editor.selectionHighlightBackground"] = blueHighlight;
	output.colors["editor.selectionHighlightBorder"] = blueHighlightBorder;
	output.colors["editor.wordHighlightBackground"] = blueHighlight;
	output.colors["editor.wordHighlightStrongBackground"] = blueHighlightStrong;
	output.colors["editor.wordHighlightBorder"] = blueHighlightBorder;
	output.colors["editor.wordHighlightStrongBorder"] = blueHighlightBorder;
	output.colors["editor.findMatchBorder"] = blueHighlightBorder;
	output.colors["editor.findMatchHighlightBorder"] = blueHighlightBorder;
	output.colors["editor.rangeHighlightBorder"] = blueHighlightBorder;
	output.colors["editor.hoverHighlightBackground"] = blueHighlightSoft;
	output.colors["editor.findRangeHighlightBackground"] = blueHighlightSoft;
	output.colors["editor.lineHighlightBackground"] = blueHighlightSoft;

	// Errors and diagnostics
	output.colors["errorForeground"] = variant.error;
	output.colors["editorError.foreground"] = variant.error;
	output.colors["editorWarning.foreground"] = variant.warning;
	output.colors["editorInfo.foreground"] = variant.info;
	output.colors["editorHint.foreground"] = variant.success;

	// Terminal
	output.colors["terminal.background"] = variant.background;
	output.colors["terminal.foreground"] = variant.foreground;
	output.colors["terminal.ansiBlack"] = terminalAnsi.black;
	output.colors["terminal.ansiRed"] = terminalAnsi.red;
	output.colors["terminal.ansiGreen"] = terminalAnsi.green;
	output.colors["terminal.ansiYellow"] = terminalAnsi.yellow;
	output.colors["terminal.ansiBlue"] = terminalAnsi.blue;
	output.colors["terminal.ansiMagenta"] = terminalAnsi.magenta;
	output.colors["terminal.ansiCyan"] = terminalAnsi.cyan;
	output.colors["terminal.ansiWhite"] = terminalAnsi.white;
	output.colors["terminal.ansiBrightBlack"] = terminalAnsi.brightBlack;
	output.colors["terminal.ansiBrightRed"] = terminalAnsi.brightRed;
	output.colors["terminal.ansiBrightGreen"] = terminalAnsi.brightGreen;
	output.colors["terminal.ansiBrightYellow"] = terminalAnsi.brightYellow;
	output.colors["terminal.ansiBrightBlue"] = terminalAnsi.brightBlue;
	output.colors["terminal.ansiBrightMagenta"] = terminalAnsi.brightMagenta;
	output.colors["terminal.ansiBrightCyan"] = terminalAnsi.brightCyan;
	output.colors["terminal.ansiBrightWhite"] = terminalAnsi.brightWhite;
	output.colors["editorGroupHeader.tabsBorder"] = transparent;
	output.colors["tab.border"] = transparent;
	output.colors["tab.activeBorder"] = transparent;
	output.colors["tab.activeBorderTop"] = variant.borderActive;
	output.colors["tab.unfocusedActiveBorder"] = transparent;
	output.colors["tab.unfocusedActiveBorderTop"] = unfocusedTopBorder;

	const gitModified = variant.syntax.variable;
	output.colors["gitDecoration.addedResourceForeground"] =
		variant.syntax.string;
	output.colors["gitDecoration.modifiedResourceForeground"] = gitModified;
	output.colors["gitDecoration.deletedResourceForeground"] =
		variant.syntax.keyword;
	output.colors["gitDecoration.renamedResourceForeground"] =
		variant.syntax.method;
	output.colors["gitDecoration.untrackedResourceForeground"] =
		variant.syntax.string;
	output.colors["gitDecoration.ignoredResourceForeground"] =
		`${variant.foregroundMuted}66`;
	output.colors["gitDecoration.conflictingResourceForeground"] =
		variant.warning;
	output.colors["gitDecoration.submoduleResourceForeground"] =
		variant.syntax.type;
	output.colors["gitDecoration.stageAddedResourceForeground"] = gitModified;
	output.colors["gitDecoration.stageModifiedResourceForeground"] = gitModified;
	output.colors["gitDecoration.stageDeletedResourceForeground"] = gitModified;
	output.colors["gitDecoration.stageRenamedResourceForeground"] = gitModified;
	output.colors["gitDecoration.stageUntrackedResourceForeground"] =
		variant.syntax.string;

	return output;
}

export const vscodeApp: CreateInstallModule = {
	appName: "vscode",
	async create(tokens: ThemeTokens) {
		const darkSource = await readJsonc<any>(PATHS.templates.vscode.dark);
		const lightSource = await readJsonc<any>(PATHS.templates.vscode.light);

		const darkTheme = updateVscodeTheme(
			darkSource,
			tokens.variants.dark,
			"gtheme-dark",
		);
		const lightTheme = updateVscodeTheme(
			lightSource,
			tokens.variants.light,
			"gtheme-light",
		);

		await writeJson(PATHS.output.vscode.dark, darkTheme);
		await writeJson(PATHS.output.vscode.light, lightTheme);

		return [PATHS.output.vscode.dark, PATHS.output.vscode.light];
	},
	async install() {
		await installFile(PATHS.output.vscode.dark, PATHS.install.vscode.dark);
		await installFile(PATHS.output.vscode.light, PATHS.install.vscode.light);
		return [PATHS.install.vscode.dark, PATHS.install.vscode.light];
	},
};
