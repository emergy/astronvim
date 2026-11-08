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
    local platform = require "user_platform"
    if platform.termux then
      require("treesitter_termux").setup()
    elseif platform.nix_on_droid then
      require("treesitter_build").setup()
    end
    require "astronvim.plugins.configs.nvim-treesitter"(plugin, opts)
  end,
  opts = function(_, opts)
    opts.indent = opts.indent or {}
    opts.indent.disable = require("astrocore").list_insert_unique(opts.indent.disable, { "yaml" })
    local platform = require "user_platform"
    if platform.testing then
      opts.auto_install = false
      opts.ensure_installed = {}
    elseif opts.ensure_installed ~= "all" then
      opts.ensure_installed = require("astrocore").list_insert_unique(opts.ensure_installed, { "lua", "vim" })
    end
  end,
}
