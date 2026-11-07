---@type LazySpec
return {
  "stevearc/aerial.nvim",
  opts = function() require("treesitter_compat").setup_aerial() end,
}
