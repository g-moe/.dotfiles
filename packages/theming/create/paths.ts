import os from "os";
import path from "path";

const HOME = os.homedir();
const ROOT = path.join(HOME, ".dotfiles");
const THEMING = path.join(ROOT, "packages/theming");
const CREATE_ROOT = path.join(THEMING, "create");
const OUTPUT_ROOT = path.join(THEMING, "output");
const VSCE_PACKAGE = path.join(THEMING, "vsce-package");

export const PATHS = {
	root: ROOT,
	theming: THEMING,
	createRoot: CREATE_ROOT,
	outputRoot: OUTPUT_ROOT,
	vscePackage: VSCE_PACKAGE,
	tokens: path.join(CREATE_ROOT, "tokens.css"),
	templates: {
		vscode: {
			dark: path.join(VSCE_PACKAGE, "themes/gtheme-dark.json"),
			light: path.join(VSCE_PACKAGE, "themes/gtheme-light.json"),
		},
	},
	output: {
		vscode: {
			dark: path.join(OUTPUT_ROOT, "vscode/gtheme-dark.json"),
			light: path.join(OUTPUT_ROOT, "vscode/gtheme-light.json"),
		},
		opencode: {
			theme: path.join(OUTPUT_ROOT, "opencode/gtheme.json"),
		},
		ghostty: {
			dark: path.join(OUTPUT_ROOT, "ghostty/gtheme-dark"),
			light: path.join(OUTPUT_ROOT, "ghostty/gtheme-light"),
		},
		nvim: {
			dark: path.join(OUTPUT_ROOT, "nvim/gtheme-dark.lua"),
			light: path.join(OUTPUT_ROOT, "nvim/gtheme-light.lua"),
		},
		"oh-my-zsh": {
			dark: path.join(OUTPUT_ROOT, "oh-my-zsh/gtheme-dark.zsh-theme"),
			light: path.join(OUTPUT_ROOT, "oh-my-zsh/gtheme-light.zsh-theme"),
		},
	},
	install: {
		vscode: {
			dark: path.join(VSCE_PACKAGE, "themes/gtheme-dark.json"),
			light: path.join(VSCE_PACKAGE, "themes/gtheme-light.json"),
		},
		opencode: {
			theme: path.join(ROOT, "opencode/themes/gtheme.json"),
		},
		ghostty: {
			dark: path.join(ROOT, "ghostty/themes/gtheme-dark"),
			light: path.join(ROOT, "ghostty/themes/gtheme-light"),
		},
		nvim: {
			dark: path.join(ROOT, "nvim/colors/gtheme-dark.lua"),
			light: path.join(ROOT, "nvim/colors/gtheme-light.lua"),
		},
		"oh-my-zsh": {
			dark: path.join(HOME, ".oh-my-zsh/custom/themes/gtheme-dark.zsh-theme"),
			light: path.join(HOME, ".oh-my-zsh/custom/themes/gtheme-light.zsh-theme"),
		},
	},
} as const;
