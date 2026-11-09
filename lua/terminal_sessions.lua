local M = {}
local contexts = {}
local context = require "terminal_context"

local function terminals()
  local loaded = package.loaded["toggleterm.terminal"]
  return loaded and loaded.get_all() or {}
end

function M.label(term, compact)
  local info = contexts[term.id] or context.inspect(term)
  return ("%d: %s"):format(term.id, context.format(info, compact))
end

function M.buffer_label(buf)
  for _, term in ipairs(terminals()) do
    if term.bufnr == buf then return M.label(term) end
  end
  return context.format(context.inspect { bufnr = buf, job_id = vim.b[buf].terminal_job_id })
end

function M.title()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype == "terminal" then return M.buffer_label(buf) .. " " end
  local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
  return (name == "" and "[No Name]" or name) .. " [" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t") .. "] "
end

function M.refresh()
  local updated, changed = {}, false
  for _, term in ipairs(terminals()) do
    updated[term.id] = context.inspect(term)
    if not vim.deep_equal(updated[term.id], contexts[term.id]) then changed = true end
  end
  contexts = updated
  if changed then
    vim.cmd "redrawstatus!"
    vim.o.titlestring = vim.o.titlestring
  end
end

function M.setup()
  _G.NvimTerminalSessionClick = M.click
  if M.timer then return end
  M.timer = assert((vim.uv or vim.loop).new_timer())
  M.timer:start(0, 750, vim.schedule_wrap(M.refresh))
  vim.api.nvim_create_autocmd("VimLeavePre", {
    once = true,
    callback = function()
      M.timer:stop()
      M.timer:close()
    end,
  })
end

function M.click(id, _, button)
  if button and button ~= "l" then return end
  local term = require("toggleterm.terminal").get(id)
  if not term then return end
  local win = vim.fn.getmousepos().winid
  if win > 0 and vim.api.nvim_win_is_valid(win) and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "terminal" then
    vim.api.nvim_set_current_win(win)
  end
  return M.activate(term)
end

local function slot()
  local buf = vim.api.nvim_get_current_buf()
  local other
  for _, term in ipairs(terminals()) do
    term.window = require("terminal_zoom").window(term)
    if term.window and vim.api.nvim_win_get_tabpage(term.window) == vim.api.nvim_get_current_tabpage() then
      if term.bufnr == buf then return term end
      if not term.hidden then other = other or term end
    end
  end
  return other
end

local function start_input(term)
  vim.cmd.startinsert()
  vim.schedule(function()
    if vim.api.nvim_get_current_buf() == term.bufnr then vim.cmd.startinsert() end
  end)
end

-- Единственный путь для F8, таббара и создания сессии. Zoom не владеет PTY.
function M.activate(term, options)
  options = options or {}
  local zoom = require "terminal_zoom"
  local previous = options.slot or slot()
  local zoomed = options.zoomed or (previous and zoom.active(previous.bufnr))
  term.window = zoom.window(term)
  if term.bufnr and zoom.active(term.bufnr) then
    vim.api.nvim_set_current_win(require("snacks").zen.win.win)
    start_input(term)
    return vim.api.nvim_get_current_win()
  end
  if zoom.active() then require("snacks").zen.zoom() end
  if term.window then
    vim.api.nvim_set_current_win(term.window)
  else
    local target = previous and zoom.window(previous)
    if target then
      term.direction = previous.direction
      if not term.bufnr or not vim.api.nvim_buf_is_valid(term.bufnr) then term:spawn() end
      for _, old in ipairs(require("toggleterm.terminal").get_all(true)) do
        if old.window == target then old.window = nil end
      end
      term.window = target
      require("window_roles").claim(target, "terminal", term.bufnr)
      vim.api.nvim_set_current_win(target)
      vim.api.nvim_win_set_buf(target, term.bufnr)
      term:__set_options()
      require("toggleterm.ui").set_winbar(term)
      if term.on_open then term:on_open() end
    else
      term:open(nil, "horizontal")
    end
  end
  if zoomed and not require("user_platform").mobile then
    require("snacks").zen.zoom { zoom = { win = { height = 0 } } }
  else
    zoom.open(term)
  end
  start_input(term)
  return vim.api.nvim_get_current_win()
end

function M.new()
  local previous = slot()
  local term = require("toggleterm.terminal").Terminal:new { direction = "horizontal" }
  -- Не отправляем строку команды или управляющие клавиши работающей оболочке.
  M.activate(term, { slot = previous })
  return term
end

function M.select()
  M.refresh()
  local terminals = require("toggleterm.terminal").get_all()
  if #terminals == 0 then
    M.new()
    return
  end
  local previous = slot()
  local zoomed = previous and require("terminal_zoom").active(previous.bufnr)

  local width = 0
  for _, term in ipairs(terminals) do
    width = math.max(width, vim.fn.strdisplaywidth(M.label(term)) + 6)
  end
  local maximum = math.max(1, vim.o.columns - 4)
  vim.ui.select(terminals, {
    snacks = {
      layout = {
        layout = {
          width = math.min(maximum, math.max(80, width)),
          min_width = math.min(80, maximum),
          max_width = maximum,
        },
      },
    },
    prompt = "Выберите терминал:",
    format_item = M.label,
  }, function(term)
    if not term then return end
    M.activate(term, { slot = previous, zoomed = zoomed })
  end)
end

return M
