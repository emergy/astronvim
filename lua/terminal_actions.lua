local M = {}

local function current()
  local buf = vim.api.nvim_get_current_buf()
  for _, term in ipairs(require("toggleterm.terminal").get_all(true)) do
    if term.bufnr == buf then return term end
  end
end

local function unzoom()
  if require("terminal_zoom").active() then require("snacks").zen.zoom() end
end

local function ensure_editor()
  local roles = require "window_roles"
  if not roles.destination "editor" then
    local origin = vim.api.nvim_get_current_win()
    roles.open(vim.api.nvim_create_buf(true, false))
    if vim.api.nvim_win_is_valid(origin) then vim.api.nvim_set_current_win(origin) end
  end
end

function M.split(direction)
  local terminal = vim.bo.buftype == "terminal"
  unzoom()
  vim.cmd.stopinsert()
  vim.cmd(direction == "vertical" and "belowright vsplit" or "belowright split")
  local win = vim.api.nvim_get_current_win()
  if terminal then
    local term = require("toggleterm.terminal").Terminal:new { direction = direction }
    term:spawn()
    term.window = win
    require("window_roles").claim(win, "terminal", term.bufnr)
    vim.api.nvim_win_set_buf(win, term.bufnr)
    term:__set_options()
    require("toggleterm.ui").set_winbar(term)
    if term.on_open then term:on_open() end
    vim.cmd.startinsert()
    return term
  end
  require("window_roles").claim(win, "editor")
  return win
end

local function destroy(term)
  term.window = require("terminal_zoom").window(term)
  -- shutdown уже удаляет буфер: поздний on_exit не должен уводить фокус
  -- в origin_window ToggleTerm или закрывать окно другой сессии.
  term.close_on_exit = false
  if term.on_close then term:on_close() end
  local win = term.window
  term.window = nil
  if win and vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  term:shutdown()
end

function M.close_current()
  local term = current()
  if term then
    local replacement
    for _, other in ipairs(require("toggleterm.terminal").get_all()) do
      if other ~= term and not require("terminal_zoom").window(other) then replacement = other end
    end
    if replacement and not term.hidden then
      require("terminal_sessions").activate(replacement)
    else
      unzoom()
      ensure_editor()
    end
    destroy(term)
    return
  end
  unzoom()
  if vim.bo.buftype == "terminal" then
    ensure_editor()
    local buf = vim.api.nvim_get_current_buf()
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    end
    vim.api.nvim_buf_delete(buf, { force = true })
  elseif #vim.api.nvim_tabpage_list_wins(0) > 1 then
    vim.cmd "confirm close"
  else
    require("astrocore.buffer").close()
  end
end

function M.close_all(keep_current)
  local terms = require("toggleterm.terminal").get_all()
  if #terms == 0 then return end
  local keep = keep_current and current() or nil
  if keep_current and (not keep or keep.hidden) then
    vim.notify("Выберите терминал, который нужно оставить", vim.log.levels.INFO)
    return
  end
  if not keep_current then
    local active = current()
    if active and not active.hidden then unzoom() end
    ensure_editor()
  end
  for _, term in ipairs(terms) do
    if term ~= keep then destroy(term) end
  end
end

return M
