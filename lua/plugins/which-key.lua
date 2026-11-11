---@type LazySpec
return {
  "folke/which-key.nvim",
  opts = function(_, opts)
    local previous = opts.filter
    opts.filter = function(mapping)
      if previous and not previous(mapping) then return false end
      return require("keymap_help").visible(mapping)
    end
  end,
}
