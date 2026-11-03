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

function M.select()
  M.refresh()
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
