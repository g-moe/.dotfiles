-- Install lazy.nvim under Neovim's data directory.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

-- Bootstrap lazy.nvim automatically when it is missing.
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  -- Use the stable lazy.nvim branch.
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"

  -- Clone lazy.nvim with a partial clone to keep the download small.
  local output = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    lazyrepo,
    lazypath,
  })

  -- Stop startup with a readable error if cloning lazy.nvim failed.
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { output, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end

-- Add lazy.nvim to Neovim's runtime path before loading it.
vim.opt.rtp:prepend(lazypath)

-- Configure plugins with lazy.nvim.
require("lazy").setup({
  -- Load plugin specs from lua/plugins/*.lua.
  spec = {
    { import = "plugins" },
  },

  -- Automatically install missing plugins on startup.
  install = { missing = true },

  -- Check for plugin updates quietly in the background.
  checker = { enabled = true, notify = false },

  -- Trim unused built-in runtime plugins from startup.
  performance = {
    rtp = {
      disabled_plugins = {
        -- Disable compressed-file editing support.
        "gzip",

        -- Disable tar archive editing support.
        "tarPlugin",

        -- Disable HTML export support.
        "tohtml",

        -- Disable zip archive editing support.
        "zipPlugin",
      },
    },
  },
})
