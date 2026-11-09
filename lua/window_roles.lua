-- Роль принадлежит окну, а не выбранному в таббаре буферу.
local M = {}
local roles, pending = {}, {}
local busy, queued, clock = false, false, 0

local function valid(win) return win and vim.api.nvim_win_is_valid(win) end
local function kind(buf) return vim.bo[buf].buftype == "terminal" and "terminal" or "editor" end
local function eligible(win)
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].filetype == "neo-tree" then return false end
  if vim.api.nvim_win_get_config(win).relative == "" then
    return vim.bo[buf].buftype == "" or vim.bo[buf].buftype == "terminal" or vim.bo[buf].filetype == "snacks_dashboard"
  end
  local zen = package.loaded["snacks.zen"]
  return zen and zen.win and zen.win:valid() and zen.win.win == win
end

function M.claim(win, role, buf)
  if not valid(win) then return end
  roles[win] = { kind = role, buf = buf or vim.api.nvim_win_get_buf(win), used = clock }
  pending[win] = nil
end

local function adopt(win)
  if not roles[win] and eligible(win) then M.claim(win, kind(vim.api.nvim_win_get_buf(win))) end
end

function M.destination(role, buf)
  local current, best, score = vim.api.nvim_get_current_win(), nil, -1
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    adopt(win)
    local entry = roles[win]
    if
      entry
      and entry.kind == role
      and eligible(win)
      and (role ~= "terminal" or vim.api.nvim_win_get_buf(win) == buf)
    then
      local rank = entry.used
      if vim.api.nvim_win_get_buf(win) == buf then rank = rank + 1000000 end
      if win == current then rank = rank + 2000000 end
      if rank > score then
        best, score = win, rank
      end
    end
  end
  return best
end

function M.open(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return vim.api.nvim_get_current_win() end
  local role = kind(buf)
  if role == "terminal" and vim.b[buf].toggle_number then
    local term = require("toggleterm.terminal").get(vim.b[buf].toggle_number, true)
    if term and not term.hidden then return require("terminal_sessions").activate(term) end
  end
  local zen = package.loaded["snacks.zen"]
  if zen and zen.win and zen.win:valid() and kind(zen.win.buf) ~= role then zen.zoom() end
  local target = M.destination(role, buf)
  if not target then
    vim.cmd(role == "terminal" and "botright 20split" or "aboveleft vsplit")
    target = vim.api.nvim_get_current_win()
    M.claim(target, role, buf)
  end
  vim.cmd.stopinsert()
  vim.api.nvim_set_current_win(target)
  vim.api.nvim_win_set_buf(target, buf)
  M.claim(target, role, buf)
  if role == "terminal" then vim.cmd.startinsert() end
  return target
end

local function check()
  queued = false
  if busy then return end
  busy = true
  local redirect
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    adopt(win)
    local entry = roles[win]
    if entry then
      local buf = vim.api.nvim_win_get_buf(win)
      if kind(buf) ~= entry.kind then
        redirect = redirect or buf
        if not vim.api.nvim_buf_is_valid(entry.buf) or kind(entry.buf) ~= entry.kind then
          if entry.kind == "editor" then
            -- :terminal может превратить исходный пустой буфер в PTY на месте.
            entry.buf = vim.api.nvim_create_buf(true, false)
          else
            -- Закрытый PTY не превращает его оставшееся окно в редактор.
            if #vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(win)) == 1 then
              vim.api.nvim_win_call(win, function()
                vim.cmd.vsplit()
                local replacement = vim.api.nvim_get_current_win()
                M.claim(replacement, "editor", buf)
              end)
            end
            vim.api.nvim_win_close(win, true)
          end
        end
        if valid(win) then vim.api.nvim_win_set_buf(win, entry.buf) end
      elseif kind(buf) == entry.kind then
        entry.buf = buf
      end
    end
  end
  busy = false
  if redirect then M.open(redirect) end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("PanelWindowRoles", { clear = true })
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    adopt(win)
  end
  vim.api.nvim_create_autocmd("WinNew", {
    group = group,
    callback = function(args)
      local win = tonumber(args.match)
      if win then pending[win] = true end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "WinEnter", "TermOpen" }, {
    group = group,
    callback = function()
      if busy or queued then return end
      queued = true
      vim.schedule(function()
        -- Дать создателю split назначить конечный буфер до определения роли.
        for win in pairs(pending) do
          if valid(win) then adopt(win) end
          pending[win] = nil
        end
        check()
      end)
      clock = clock + 1
      local entry = roles[vim.api.nvim_get_current_win()]
      if entry then entry.used = clock end
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(args)
      roles[tonumber(args.match)], pending[tonumber(args.match)] = nil, nil
    end,
  })
end

return M
