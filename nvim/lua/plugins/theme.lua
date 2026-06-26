return {
  -- Install the Nord colorscheme.
  "shaunsingh/nord.nvim",

  -- Load the theme immediately so it applies on startup.
  lazy = false,

  -- Give the theme high priority so it loads before other visual plugins.
  priority = 1000,

  -- Apply Nord after the plugin loads.
  config = function()
    vim.cmd.colorscheme("nord")
  end,
}
