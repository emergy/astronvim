local M = {}

function M.setup() require("treesitter_build").setup { "clang", "cc" } end

return M
