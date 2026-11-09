local M = {}

function M.close(buf)
  if type(buf) ~= "number" or not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].buflisted then return end
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then require("astrocore.buffer").close(buf) end
  end)
end

function M.middle()
  local mouse = vim.fn.getmousepos()
  local win = mouse.winid
  if win > 0 and vim.api.nvim_win_is_valid(win) then
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "neo-tree" and vim.b[buf].neo_tree_source == "buffers" then
      local tab = vim.api.nvim_win_get_tabpage(win)
      local current = vim.b[buf].neo_tree_position == "current" and win or nil
      local state = require("neo-tree.sources.manager").get_state("buffers", tab, current)
      local node = state.tree and state.tree:get_node(mouse.line)
      M.close(node and node.extra and node.extra.bufnr)
      return
    end
  end
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<MiddleMouse>", true, false, true), "n", false)
end

function M.patch_tabline(component)
  if type(component) ~= "table" then return end
  local click = component.on_click
  if type(click) == "table" and click.name == "heirline_tabline_buffer_callback" and not click.panel_routing then
    click.panel_routing = true
    click.callback = function(self, buf, clicks, button, mods)
      if button == "m" then
        M.close(buf)
      else
        require("window_roles").open(buf)
      end
    end
  end
  for _, child in ipairs(component) do
    M.patch_tabline(child)
  end
end

function M.setup()
  vim.keymap.set(
    { "n", "i", "t", "x" },
    "<MiddleMouse>",
    M.middle,
    { desc = "Закрыть буфер под мышью в Neo-tree Bufs", silent = true }
  )
end

return M
