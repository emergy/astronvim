-- ничего не делать, если не используется VSCode
if not vim.g.vscode then return {} end

-- список известных работающих плагинов с vscode-neovim, обновите его своими плагинами
local plugins = {
  "lazy.nvim",
  "AstroNvim",
  "astrocore",
  "astroui",
  "Comment.nvim",
  "nvim-autopairs",
  "nvim-treesitter",
  "nvim-ts-autotag",
  "nvim-treesitter-textobjects",
  "nvim-ts-context-commentstring",
  "petertriho/nvim-scrollbar",
}

local Config = require "lazy.core.config"
-- отключить проверку обновлений плагинов
Config.options.checker.enabled = false
Config.options.change_detection.enabled = false
-- заменить стандартное условие `cond`
Config.options.defaults.cond = function(plugin) return vim.tbl_contains(plugins, plugin.name) end

vim.o.number = true
vim.o.relativenumber = true

---@type LazySpec
return {
  -- добавить несколько сочетаний клавиш
  {
    "AstroNvim/astrocore",
    ---@type AstroCoreOpts
    opts = {
      mappings = {
        n = {
          ["<Leader>ff"] = "<CMD>Find<CR>",
          ["<Leader>fw"] = "<CMD>call VSCodeNotify('workbench.action.findInFiles')<CR>",
          ["<Leader>ls"] = "<CMD>call VSCodeNotify('workbench.action.gotoSymbol')<CR>",
        },
      },
    },
  },
  -- отключить установку цветовой схемы
  { "AstroNvim/astroui", opts = { colorscheme = false } },
  -- отключить подсветку в treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { highlight = { enable = false } },
  },
}
