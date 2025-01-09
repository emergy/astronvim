-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.completion.copilot-lua" },
  { -- further customize the options set by the community
    "copilot.lua",
    opts = {
      suggestion = {
        keymap = {
          accept = "<M-k>",
          accept_word = "<M-l>",
          accept_line = "<M-o>",
          next = "<M-]>",
          prev = "<M-[>",
          dismiss = "<C/>",
        },
      },
    },
  },
  { import = "astrocommunity.pack.python" },
  { import = "astrocommunity.pack.ansible" },
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.pack.docker" },
  -- { import = "astrocommunity.pack.go" },
  { import = "astrocommunity.pack.helm" },
  { import = "astrocommunity.pack.json" },
  { import = "astrocommunity.pack.json" },
  { import = "astrocommunity.pack.markdown" },
  { import = "astrocommunity.pack.typescript" },
  { import = "astrocommunity.remote-development.remote-sshfs-nvim" },
  { import = "astrocommunity.utility.lua-json5" },
  { import = "astrocommunity.recipes.telescope-nvchad-theme" },
  { import = "astrocommunity.pack.terraform" },
  -- {
  --   import = "astrocommunity.snippet.nvim-snippets",
  --   opts = {
  --     search_paths = {
  --       vim.fn.stdpath "config" .. "/snippets",
  --     },
  --     keys = {
  --       {
  --         "<Tab>",
  --         function()
  --           if vim.snippet.active { direction = 1 } then
  --             vim.schedule(function() vim.snippet.jump(1) end)
  --             return
  --           end
  --           return "<Tab>"
  --         end,
  --         expr = true,
  --         silent = true,
  --         mode = "i",
  --       },
  --       {
  --         "<Tab>",
  --         function()
  --           vim.schedule(function() vim.snippet.jump(1) end)
  --         end,
  --         expr = true,
  --         silent = true,
  --         mode = "s",
  --       },
  --       {
  --         "<S-Tab>",
  --         function()
  --           if vim.snippet.active { direction = -1 } then
  --             vim.schedule(function() vim.snippet.jump(-1) end)
  --             return
  --           end
  --           return "<S-Tab>"
  --         end,
  --         expr = true,
  --         silent = true,
  --         mode = { "i", "s" },
  --       },
  --     },
  --   },
  -- },
}
