---@type LazySpec
return {
  "akinsho/toggleterm.nvim",
  cmd = { "TermSelect", "ToggleTermSetName" },
  keys = {
    {
      "<F8>",
      function()
        vim.cmd.stopinsert()
        vim.schedule(function()
          require("terminal_sessions").select()
        end)
      end,
      mode = { "n", "i", "t" },
      desc = "Select terminal or open horizontal terminal",
    },
  },
  opts = function(_, opts)
    opts.auto_scroll = false
    require("terminal_sessions").setup()
    opts.winbar = {
      enabled = true,
      name_formatter = function(term) return require("terminal_sessions").label(term):gsub("%%", "%%%%") end,
    }
  end,
}
