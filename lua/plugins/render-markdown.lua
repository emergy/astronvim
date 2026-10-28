---@type LazySpec
return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown" },
  cmd = { "RenderMarkdown" },
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.icons" },
  opts = {
    code = {
      sign = false, -- Значок языка уже есть в заголовке блока кода.
    },
  },
}
