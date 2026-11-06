---@type LazySpec
return {
  "akinsho/toggleterm.nvim",
  cmd = { "TermSelect", "ToggleTermSetName" },
  specs = {
    {
      "AstroNvim/astrocore",
      opts = function(_, opts)
        local moved = {}
        for lhs, mapping in pairs(opts.mappings.n) do
          if lhs:match "^<Leader>t" then moved[lhs] = mapping end
        end
        for lhs, mapping in pairs(moved) do
          opts.mappings.n[lhs:gsub("^<Leader>t", "<Leader>T")] = mapping
          opts.mappings.n[lhs] = false
        end
      end,
    },
  },
  keys = {
    {
      "<Leader>t",
      '<Cmd>execute v:count . "ToggleTerm"<CR>',
      mode = "n",
      nowait = true,
      desc = "Показать / скрыть терминал",
    },
    {
      "<F8>",
      function()
        vim.cmd.stopinsert()
        vim.schedule(function() require("terminal_sessions").select() end)
      end,
      mode = { "n", "i", "t" },
      desc = "Select terminal or open horizontal terminal",
    },
  },
  opts = function(_, opts)
    opts.size = 20
    opts.auto_scroll = false
    if require("user_platform").termux then require("terminal_zoom").setup(opts) end
    require("terminal_sessions").setup()
    opts.winbar = {
      enabled = true,
      name_formatter = function(term) return require("terminal_sessions").label(term, true):gsub("%%", "%%%%") end,
    }
  end,
}
