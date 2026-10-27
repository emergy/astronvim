---@type LazySpec
return {
  "smoka7/hop.nvim",
  version = "*",
  opts = {},
  keys = {
    {
      "<Leader>j",
      function() require("hop").hint_lines { multi_windows = false } end,
      mode = "n",
      desc = "Выбрать строку по метке",
    },
  },
}
