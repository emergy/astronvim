return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function() require("embedded_blocks").setup() end,
  },
}
