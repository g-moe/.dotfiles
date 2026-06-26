-- Use Space as the main leader key for custom shortcuts.
vim.g.mapleader = " "

-- Use backslash as the local leader for filetype-specific shortcuts.
vim.g.maplocalleader = "\\"

-- Clear search highlighting with Escape in normal mode.
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Use "U" for redo and keep delete "u" undo
vim.keymap.set("n", "U", "<C-r>", { desc = "Redo" })