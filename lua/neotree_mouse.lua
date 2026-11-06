local M = {}

function M.scroll(key)
  local mouse = vim.fn.getmousepos()
  local current = vim.api.nvim_get_current_win()
  if
    mouse.winid > 0
    and mouse.winid ~= current
    and vim.api.nvim_win_is_valid(mouse.winid)
    and vim.api.nvim_win_get_config(mouse.winid).focusable ~= false
  then
    local mode = vim.api.nvim_get_mode().mode
    if mode == "v" or mode == "V" or mode == "\22" then
      vim.cmd.normal { args = { vim.api.nvim_replace_termcodes("<Esc>", true, false, true) }, bang = true }
    end
    vim.cmd.stopinsert()
    vim.api.nvim_set_current_win(mouse.winid)
  end
  -- Replay the native wheel event without remapping it back into this handler.
  local count = vim.v.count > 0 and tostring(vim.v.count) or ""
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(count .. key, true, false, true), "n", false)
end

function M.setup()
  for _, direction in ipairs { "Up", "Down", "Left", "Right" } do
    local key = "<ScrollWheel" .. direction .. ">"
    vim.keymap.set(
      { "n", "i", "t", "x" },
      key,
      function() M.scroll(key) end,
      { desc = "Активировать и прокрутить панель под мышью", silent = true }
    )
  end
end

return M
