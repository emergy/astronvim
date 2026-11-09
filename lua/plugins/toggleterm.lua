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
  keys = function()
    local keys = {
      {
        "<Leader>tT",
        function()
          vim.schedule(function() require("terminal_sessions").select() end)
        end,
        desc = "Выбрать терминал (F8)",
      },
      {
        "<Leader>t[",
        function()
          vim.schedule(function() require("terminal_sessions").cycle(-1) end)
        end,
        desc = "Предыдущий терминал",
      },
      {
        "<Leader>t]",
        function()
          vim.schedule(function() require("terminal_sessions").cycle(1) end)
        end,
        desc = "Следующий терминал",
      },
      {
        "<Leader>td",
        function() require("terminal_actions").devcontainer() end,
        desc = "Devcontainer: d-c up в новой сессии",
      },
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
    }
    for digit = 0, 9 do
      local id = digit == 0 and 10 or digit
      keys[#keys + 1] = {
        "<Leader>" .. digit,
        function()
          vim.schedule(function() require("terminal_sessions").by_id(id) end)
        end,
        desc = "Терминал №" .. id,
      }
    end
    return keys
  end,
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
