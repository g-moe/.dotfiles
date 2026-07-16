import { PATHS } from "../paths";
import type { CreateInstallModule, ThemeTokens, Variant } from "../types";
import { installFile, writeText } from "../utils";

function colorTable(v: Variant): string {
	return `{
  bg = "${v.background}",
  bg_panel = "${v.backgroundPanel}",
  bg_element = "${v.backgroundElement}",
  fg = "${v.foreground}",
  fg_muted = "${v.foregroundMuted}",
  border = "${v.border}",
  border_active = "${v.borderActive}",
  primary = "${v.primary}",
  secondary = "${v.secondary}",
  accent = "${v.accent}",
  error = "${v.error}",
  warning = "${v.warning}",
  success = "${v.success}",
  info = "${v.info}",
  comment = "${v.syntax.comment}",
  keyword = "${v.syntax.keyword}",
  fn = "${v.syntax.function}",
  method = "${v.syntax.method}",
  string = "${v.syntax.string}",
  number = "${v.syntax.number}",
  type = "${v.syntax.type}",
  variable = "${v.syntax.variable}",
  operator = "${v.syntax.operator}",
  punctuation = "${v.syntax.punctuation}",
  cursor = "${v.cursor}",
  selection = "${v.selectionBackground}"
}`;
}

function buildNvimTheme(tokens: ThemeTokens, mode: "dark" | "light"): string {
	return `local M = {}

M.setup = function()
  vim.cmd("highlight clear")
  if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
  end

  vim.g.colors_name = "tradester"

  local palette = {
    dark = ${colorTable(tokens.variants.dark)},
    light = ${colorTable(tokens.variants.light)}
  }

  local c = palette["${mode}"]
  local set = vim.api.nvim_set_hl

  set(0, "Normal", { fg = c.fg, bg = c.bg })
  set(0, "NormalFloat", { fg = c.fg, bg = c.bg_panel })
  set(0, "FloatBorder", { fg = c.border_active, bg = c.bg_panel })
  set(0, "Cursor", { fg = c.bg, bg = c.cursor })
  set(0, "Visual", { fg = c.fg, bg = c.selection })
  set(0, "Comment", { fg = c.comment, italic = true })
  set(0, "Keyword", { fg = c.keyword, bold = true })
  set(0, "Function", { fg = c.fn, bold = true })
  set(0, "Identifier", { fg = c.variable })
  set(0, "String", { fg = c.string })
  set(0, "Number", { fg = c.number })
  set(0, "Type", { fg = c.type })
  set(0, "Operator", { fg = c.operator })
  set(0, "Delimiter", { fg = c.punctuation })
  set(0, "Error", { fg = c.error })
  set(0, "WarningMsg", { fg = c.warning })
  set(0, "DiffAdd", { fg = c.success, bg = c.bg_element })
  set(0, "DiffDelete", { fg = c.error, bg = c.bg_element })
  set(0, "DiffChange", { fg = c.info, bg = c.bg_element })
  set(0, "DiffText", { fg = c.accent, bg = c.bg_panel })

  set(0, "@comment", { link = "Comment" })
  set(0, "@keyword", { link = "Keyword" })
  set(0, "@function", { link = "Function" })
  set(0, "@function.method", { fg = c.method })
  set(0, "@variable", { link = "Identifier" })
  set(0, "@string", { link = "String" })
  set(0, "@number", { link = "Number" })
  set(0, "@type", { link = "Type" })
  set(0, "@operator", { link = "Operator" })
  set(0, "@punctuation", { link = "Delimiter" })
end

M.setup()

return M
`;
}

export const nvimApp: CreateInstallModule = {
	appName: "nvim",
	async create(tokens: ThemeTokens) {
		await writeText(PATHS.output.nvim.dark, buildNvimTheme(tokens, "dark"));
		await writeText(PATHS.output.nvim.light, buildNvimTheme(tokens, "light"));
		return [PATHS.output.nvim.dark, PATHS.output.nvim.light];
	},
	async install() {
		await installFile(PATHS.output.nvim.dark, PATHS.install.nvim.dark);
		await installFile(PATHS.output.nvim.light, PATHS.install.nvim.light);
		return [PATHS.install.nvim.dark, PATHS.install.nvim.light];
	},
};
