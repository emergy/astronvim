local M = {}
local configured = false

-- Snacks показывает копию буфера; владельцем сессии остаётся обычный split.
function M.window(term)
  local zen = package.loaded["snacks.zen"]
  local zoom = zen and zen.win and zen.win:valid() and zen.win.win
  local fallback
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= zoom and vim.api.nvim_win_get_buf(win) == term.bufnr then
      if vim.api.nvim_win_get_config(win).relative == "" then return win end
      fallback = fallback or win
    end
  end
  return fallback
end

function M.active(buf)
  local zen = package.loaded["snacks.zen"]
  return zen and zen.win and zen.win:valid() and (not buf or zen.win.buf == buf) or false
end

function M.close(term)
  local zen = package.loaded["snacks.zen"]
  if zen and zen.win and zen.win:valid() and zen.win.buf == term.bufnr then zen.zoom() end
end

function M.open(term)
  if not require("user_platform").mobile or term.hidden or not term.window then return end
  if not vim.api.nvim_win_is_valid(term.window) or not term:is_split() then return end
  vim.schedule(function()
    if not term:is_open() or vim.api.nvim_get_current_buf() ~= term.bufnr then return end
    local zen = require("snacks").zen
    if zen.win and zen.win:valid() then
      if zen.win.buf == term.bufnr and vim.api.nvim_get_current_win() == zen.win.win then return end
      zen.zoom()
    end
    vim.api.nvim_set_current_win(term.window)
    zen.zoom { zoom = { win = { height = 0 } } }
    vim.cmd.startinsert()
  end)
end

function M.setup(opts)
  local on_open, on_close = opts.on_open, opts.on_close
  opts.on_open = function(term)
    require("window_roles").claim(term.window, "terminal", term.bufnr)
    if on_open then on_open(term) end
    M.open(term)
  end
  opts.on_close = function(term)
    M.close(term)
    if on_close then on_close(term) end
  end
  if configured then return end
  configured = true
  -- Snacks показывает буфер ещё и в плавающем окне. ToggleTerm должен сохранять
  -- одну сессию, иначе повторное открытие создаёт лишние сплиты для того же ID.
  local ui = require "toggleterm.ui"
  local winbar = ui.winbar
  ui.winbar = function(id) return winbar(id):gsub("v:lua%.___toggleterm_winbar_click", "v:lua.NvimTerminalSessionClick") end
  local find = ui.find_open_windows
  ui.find_open_windows = function(...)
    local _, windows = find(...)
    local filtered = {}
    for _, entry in ipairs(windows) do
      local term = require("toggleterm.terminal").get(entry.term_id)
      if term then term.window = M.window(term) end
      if not term or entry.window == term.window then filtered[#filtered + 1] = entry end
    end
    return #filtered > 0, filtered
  end
end

return M
