-- Keep option assignments short and easy to scan.
local opt = vim.opt

-- Show absolute line numbers.
opt.number = true

-- Show relative line numbers for faster vertical motions.
opt.relativenumber = true

-- Make searches case-insensitive by default.
opt.ignorecase = true

-- Make searches case-sensitive when the search contains uppercase letters.
opt.smartcase = true

-- Open vertical splits to the right.
opt.splitright = true

-- Open horizontal splits below.
opt.splitbelow = true
 
-- Enable true color support in the terminal.
opt.termguicolors = true

-- Insert spaces when pressing Tab.
opt.expandtab = true

-- Indent by two spaces.
opt.shiftwidth = 2

-- Display tab characters as two columns wide.
opt.tabstop = 2

-- Auto-indent new lines based on nearby code.
opt.smartindent = true
