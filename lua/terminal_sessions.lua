local M = {}
local process_names = {}

local function read_line(path)
  local file = io.open(path, "r")
  if not file then return end
  local line = file:read "*l"
  file:close()
  return line
end

local function process_name(term)
  local ok, pid = pcall(vim.fn.jobpid, term.job_id or -1)
  if not ok or pid <= 0 then return "terminal" end
  local stat = read_line(("/proc/%d/stat"):format(pid))
  -- Fields after the parenthesized command start at field 3; tpgid is field 8.
  local fields = stat and vim.split(stat:match("^%d+ %b() (.*)$") or "", " ", { trimempty = true })
  local foreground = fields and tonumber(fields[6])
  return read_line(("/proc/%d/comm"):format(foreground and foreground > 0 and foreground or pid))
    or vim.fn.fnamemodify(vim.o.shell, ":t")
end

function M.label(term)
  local name = process_names[term.id] or process_name(term)
  return ("%d: %s"):format(term.id, name)
end

function M.setup()
  if M.timer then return end
  M.timer = assert((vim.uv or vim.loop).new_timer())
  M.timer:start(0, 750, vim.schedule_wrap(function()
    local names = {}
    local changed = false
    for _, term in ipairs(require("toggleterm.terminal").get_all()) do
      names[term.id] = process_name(term)
      if names[term.id] ~= process_names[term.id] then changed = true end
    end
    process_names = names
    if changed then vim.cmd "redrawstatus!" end
  end))
  vim.api.nvim_create_autocmd("VimLeavePre", {
    once = true,
    callback = function()
      M.timer:stop()
      M.timer:close()
    end,
  })
end

function M.select()
  local terminals = require("toggleterm.terminal").get_all()
  if #terminals == 0 then
    vim.cmd "ToggleTerm direction=horizontal"
    return
  end

  local window = vim.api.nvim_get_current_win()
  local slot
  for _, term in ipairs(terminals) do
    if term:is_open() then
      if term.window == window then
        slot = term
        break
      end
      slot = slot or term
    end
  end

  vim.ui.select(terminals, {
    prompt = "Выберите терминал:",
    format_item = M.label,
  }, function(term)
    if not term then return end
    if term:is_open() then
      term:focus()
    elseif slot and slot:is_open() then
      -- Reuse the terminal window instead of asking ToggleTerm to create a split.
      local target_window = slot.window
      term.direction = slot.direction
      if not term.bufnr or not vim.api.nvim_buf_is_valid(term.bufnr) then term:spawn() end
      vim.api.nvim_set_current_win(target_window)
      slot.window = nil
      term.window = target_window
      vim.api.nvim_win_set_buf(target_window, term.bufnr)
      require("toggleterm.ui").set_winbar(term)
      if term.on_open then term:on_open() end
    else
      term:open(nil, "horizontal")
    end
    vim.cmd.startinsert()
  end)
end

return M
