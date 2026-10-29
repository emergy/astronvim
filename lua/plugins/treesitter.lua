-- Customize Treesitter

---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  init = function(plugin)
    require("lazy.core.loader").add_to_rtp(plugin)
    require("treesitter_compat").setup()
    pcall(require, "nvim-treesitter.query_predicates")
  end,
  config = function(plugin, opts)
    require("treesitter_compat").setup()
    require("astronvim.plugins.configs.nvim-treesitter")(plugin, opts)
  end,
  opts = function(_, opts)
    opts.indent = opts.indent or {}
    opts.indent.disable = require("astrocore").list_insert_unique(opts.indent.disable, { "yaml" })
    if require("user_platform").testing then
      opts.auto_install = false
      opts.ensure_installed = {}
    elseif opts.ensure_installed ~= "all" then
      opts.ensure_installed = require("astrocore").list_insert_unique(opts.ensure_installed, { "lua", "vim" })
    end
  end,
}
