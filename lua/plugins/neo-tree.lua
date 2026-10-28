---@type LazySpec
return {
  "nvim-neo-tree/neo-tree.nvim",
  -- Автоматически открывать дерево слева при запуске без файлов и каталогов
  -- на стартовом экране или в пустом буфере. Сейчас отключено.
  -- Чтобы включить, раскомментируйте блок init ниже и перезапустите Neovim.
  -- init = function()
  --   if vim.fn.argc(-1) > 0 then return end
  --   vim.api.nvim_create_autocmd("User", {
  --     pattern = "VeryLazy",
  --     group = vim.api.nvim_create_augroup("user_neotree_startup", { clear = true }),
  --     once = true,
  --     callback = function()
  --       vim.schedule(function()
  --         local dashboard = vim.bo.filetype == "snacks_dashboard"
  --         local empty = vim.bo.buftype == ""
  --           and vim.api.nvim_buf_get_name(0) == ""
  --           and not vim.bo.modified
  --           and vim.api.nvim_buf_line_count(0) == 1
  --           and vim.api.nvim_get_current_line() == ""
  --         if dashboard or empty then
  --           require("neo-tree.command").execute { action = "show", source = "filesystem", position = "left" }
  --         end
  --       end)
  --     end,
  --   })
  -- end,
  opts = {
    filesystem = {
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
      },
    },
  },
  dependencies = {
    "smoka7/hop.nvim",
  },
}
