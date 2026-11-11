---@type LazySpec
return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      actions = {
        toggle_help_input = function(picker) require("keymap_help").toggle(picker.input.win) end,
        toggle_help_list = function(picker) require("keymap_help").toggle(picker.list.win) end,
      },
    },
  },
  keys = function()
    local keys = {
      {
        "<M-z>",
        function()
          local insert = vim.api.nvim_get_mode().mode:match "^[it]" ~= nil
          vim.cmd.stopinsert()
          vim.schedule(function()
            require("snacks").zen.zoom { zoom = { win = { height = 0 } } }
            if insert then vim.cmd.startinsert() end
          end)
        end,
        mode = { "n", "i" },
        desc = "Развернуть панель / восстановить раскладку",
      },
      {
        "<M-z>",
        [[<C-\><C-n><Cmd>lua require("snacks").zen.zoom({zoom = {win = {height = 0}}}); vim.cmd.startinsert()<CR>]],
        mode = "t",
        desc = "Развернуть панель / восстановить раскладку",
      },
    }
    for index = 1, 2 do
      local alias = vim.deepcopy(keys[index])
      alias[1] = "<C-S-Up>"
      keys[#keys + 1] = alias
    end
    return keys
  end,
}
