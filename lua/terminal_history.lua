local M = {}
local pending = {}

function M.clear()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype ~= "terminal" or pending[buf] then return end
  pending[buf] = vim.bo[buf].scrollback
  -- Neovim применяет сокращение истории при следующем обновлении терминала.
  vim.bo[buf].scrollback = 1
  vim.defer_fn(function()
    local previous = pending[buf]
    pending[buf] = nil
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal" then vim.bo[buf].scrollback = previous end
  end, 100)
end

return M
