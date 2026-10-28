local plugins = vim.fn.stdpath "data" .. "/lazy/"
for _, name in ipairs { "plenary.nvim", "nui.nvim", "neo-tree.nvim" } do
  vim.opt.runtimepath:prepend(plugins .. name)
end
local spec = dofile(vim.fn.stdpath "config" .. "/lua/plugins/neo-tree.lua")
local expect_tree = vim.fn.argc(-1) == 0
local original = vim.api.nvim_get_current_buf()
require("neo-tree").setup(spec.opts)
spec.init()
vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
local function has_tree()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree" then return true end
  end
  return false
end
if expect_tree then
  assert(vim.wait(2000, function() return has_tree() and vim.api.nvim_get_current_buf() == original end, 10), "Neo-tree did not open or restore focus")
  assert(vim.api.nvim_get_current_buf() == original, "startup stole focus")
else
  vim.wait(100)
  assert(not has_tree(), "Neo-tree opened with file argument")
end
print(expect_tree and "PASS: no arguments opens Neo-tree without stealing focus" or "PASS: file argument does not open Neo-tree")
