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
        opts.mappings.n["<Leader>t"] = { desc = "Терминалы и панели" }
      end,
    },
  },
  keys = {
    {
      "<Leader>tn",
      function() require("terminal_sessions").new() end,
      mode = "n",
      desc = "Новая сессия терминала в той же панели",
    },
    {
      "<Leader>tt",
      function() require("toggleterm").toggle() end,
      mode = "n",
      desc = "Показать / скрыть терминал",
    },
    {
      "<Leader>th",
      function() require("terminal_actions").split "horizontal" end,
      desc = "Горизонтальный сплит текущей панели",
    },
    {
      "<Leader>tv",
      function() require("terminal_actions").split "vertical" end,
      desc = "Вертикальный сплит текущей панели",
    },
    {
      "<Leader>tc",
      function() require("terminal_actions").close_current() end,
      desc = "Закрыть текущую сессию / панель",
    },
    {
      "<Leader>tC",
      function() require("terminal_actions").close_all(true) end,
      desc = "Закрыть остальные терминалы",
    },
    {
      "<Leader>tq",
      function() require("terminal_actions").close_all(false) end,
      desc = "Закрыть все терминалы",
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
    require("terminal_zoom").setup(opts)
    require("terminal_sessions").setup()
    opts.winbar = {
      enabled = true,
      name_formatter = function(term) return require("terminal_sessions").label(term, true):gsub("%%", "%%%%") end,
    }
  end,
}
