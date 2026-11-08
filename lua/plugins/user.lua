-- if true then return {} end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE

-- You can also add or configure plugins by creating files in this `plugins/` folder
-- PLEASE REMOVE THE EXAMPLES YOU HAVE NO INTEREST IN BEFORE ENABLING THIS FILE
-- Here are some examples:

---@type LazySpec
return {
  "kkrampis/codex.nvim",
  lazy = true,
  cmd = { "Codex", "CodexToggle" }, -- Optional: Load only on command execution
  keys = {
    {
      "<leader>lc", -- Change this to your preferred keybinding
      function() require("codex").toggle() end,
      desc = "Toggle Codex popup or side-panel",
      mode = { "n", "t" },
    },
  },
  opts = {
    keymaps = {
      toggle = nil, -- Keybind to toggle Codex window (Disabled by default, watch out for conflicts)
      quit = "<C-q>", -- Keybind to close the Codex window (default: Ctrl + q)
    }, -- Disable internal default keymap (<leader>cc -> :CodexToggle)
    border = "rounded", -- Options: 'single', 'double', or 'rounded'
    width = 0.33, -- Доля общей ширины Neovim для панели Codex
    height = 0.8, -- Height of the floating window (0.0 to 1.0)
    model = nil, -- Optional: pass a string to use a specific model (e.g., 'o3-mini')
    autoinstall = not (require("user_platform").system_tools or require("user_platform").testing), -- На мобильных профилях CLI ставится средствами окружения.
    panel = true, -- Открывать Codex вертикальной панелью справа
    use_buffer = false, -- Capture Codex stdout into a normal buffer instead of a terminal buffer
  },
}

--
--   -- == Examples of Adding Plugins ==
--
--   "andweeb/presence.nvim",
--   {
--     "ray-x/lsp_signature.nvim",
--     event = "BufRead",
--     config = function() require("lsp_signature").setup() end,
--   },
--
--   -- == Examples of Overriding Plugins ==
--
--   -- customize dashboard options
--   {
--     "folke/snacks.nvim",
--     opts = {
--       dashboard = {
--         preset = {
--           header = table.concat({
--             " █████  ███████ ████████ ██████   ██████ ",
--             "██   ██ ██         ██    ██   ██ ██    ██",
--             "███████ ███████    ██    ██████  ██    ██",
--             "██   ██      ██    ██    ██   ██ ██    ██",
--             "██   ██ ███████    ██    ██   ██  ██████ ",
--             "",
--             "███    ██ ██    ██ ██ ███    ███",
--             "████   ██ ██    ██ ██ ████  ████",
--             "██ ██  ██ ██    ██ ██ ██ ████ ██",
--             "██  ██ ██  ██  ██  ██ ██  ██  ██",
--             "██   ████   ████   ██ ██      ██",
--           }, "\n"),
--         },
--       },
--     },
--   },
--
--   -- You can disable default plugins as follows:
--   { "max397574/better-escape.nvim", enabled = false },
--
--   -- You can also easily customize additional setup of plugins that is outside of the plugin's setup call
--   {
--     "L3MON4D3/LuaSnip",
--     config = function(plugin, opts)
--       require "astronvim.plugins.configs.luasnip"(plugin, opts) -- include the default astronvim config that calls the setup call
--       -- add more custom luasnip configuration such as filetype extend or custom snippets
--       local luasnip = require "luasnip"
--       luasnip.filetype_extend("javascript", { "javascriptreact" })
--     end,
--   },
--
--   {
--     "windwp/nvim-autopairs",
--     config = function(plugin, opts)
--       require "astronvim.plugins.configs.nvim-autopairs"(plugin, opts) -- include the default astronvim config that calls the setup call
--       -- add more custom autopairs configuration such as custom rules
--       local npairs = require "nvim-autopairs"
--       local Rule = require "nvim-autopairs.rule"
--       local cond = require "nvim-autopairs.conds"
--       npairs.add_rules(
--         {
--           Rule("$", "$", { "tex", "latex" })
--             -- don't add a pair if the next character is %
--             :with_pair(cond.not_after_regex "%%")
--             -- don't add a pair if  the previous character is xxx
--             :with_pair(
--               cond.not_before_regex("xxx", 3)
--             )
--             -- don't move right when repeat character
--             :with_move(cond.none())
--             -- don't delete if the next character is xx
--             :with_del(cond.not_after_regex "xx")
--             -- disable adding a newline when you press <cr>
--             :with_cr(cond.none()),
--         },
--         -- disable for .vim files, but it work for another filetypes
--         Rule("a", "a", "-vim")
--       )
--     end,
--   },
-- }
