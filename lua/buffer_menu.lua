local M = {}

function M.open()
  local command = require "neo-tree.command"
  local manager = require "neo-tree.sources.manager"
  local origin = vim.api.nvim_get_current_win()
  local tab = vim.api.nvim_get_current_tabpage()
  local editor = origin
  local saved
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local state = manager.get_state_for_window(win)
    if state and (not saved or win == origin) then
      saved = {
        source = state.name,
        position = state.current_position or state.window.position,
        width = vim.api.nvim_win_get_width(win),
        view = vim.api.nvim_win_call(win, vim.fn.winsaveview),
      }
      if win == origin then break end
    end
  end
  if manager.get_state_for_window(editor) then
    editor = require("neo-tree").get_prior_window()
    if not editor or editor <= 0 or not vim.api.nvim_win_is_valid(editor) then
      vim.notify("Нет окна редактора для выбранного буфера", vim.log.levels.WARN)
      return
    end
  end

  local position = saved and saved.position or "left"
  local last = vim.deepcopy(command._last)
  local selected
  local ok, err = pcall(function()
    command.execute { action = "focus", source = "buffers", position = position }
    local state = manager.get_state "buffers"
    assert(vim.wait(1500, function()
      return state.tree and state.winid and vim.api.nvim_win_is_valid(state.winid)
        and vim.bo[vim.api.nvim_win_get_buf(state.winid)].filetype == "neo-tree"
        and not state.loading
    end, 10), "Neo-tree Bufs не успел загрузиться")
    vim.api.nvim_set_current_win(state.winid)
    if saved and position ~= "float" then vim.api.nvim_win_set_width(state.winid, saved.width) end

    local hop = require "hop"
    local opts = setmetatable({
      multi_windows = false,
      jump_on_sole_occurrence = false,
      hint_type = require("hop.hint").HintType.OVERLAY,
    }, { __index = hop.opts })
    hop.hint_with_callback(function()
      local targets, indirect = {}, {}
      local first = vim.fn.line "w0"
      local last_line = vim.fn.line "w$"
      for row = first, last_line do
        local node = state.tree:get_node(row)
        if node and node.extra and node.extra.bufnr and vim.api.nvim_buf_is_valid(node.extra.bufnr) then
          targets[#targets + 1] = {
            window = state.winid,
            buffer = state.bufnr,
            cursor = { row = row, col = 0 },
            length = 1,
          }
          indirect[#indirect + 1] = { index = #targets, score = row }
        end
      end
      return { jump_targets = targets, indirect_jump_targets = indirect }
    end, opts, function(target)
      local node = state.tree:get_node(target.cursor.row)
      selected = node and node.extra and node.extra.bufnr
    end)
  end)

  -- Restore the source and visibility even if picking was cancelled or failed.
  local restored, restore_err = pcall(function()
    if saved then
      command.execute { action = "focus", source = saved.source, position = saved.position }
      local state = manager.get_state(saved.source)
      if state.winid and vim.api.nvim_win_is_valid(state.winid) then
        if saved.position ~= "float" then vim.api.nvim_win_set_width(state.winid, saved.width) end
        vim.api.nvim_win_call(state.winid, function() vim.fn.winrestview(saved.view) end)
      end
    else
      command.execute { action = "close", source = "buffers", position = position }
    end
  end)
  command._last = last
  if selected and vim.api.nvim_buf_is_valid(selected) then
    local opened, open_err = pcall(function()
      -- Открытие дерева могло закрыть исходное окно Snacks Zoom.
      if vim.api.nvim_win_is_valid(editor) then vim.api.nvim_set_current_win(editor) end
      editor = require("window_roles").open(selected)
    end)
    if not opened then ok, err = false, open_err end
  end
  local focus = selected and editor or origin
  if vim.api.nvim_win_is_valid(focus) then vim.api.nvim_set_current_win(focus) end
  -- Neo-tree follows BufEnter with a 100 ms debounce; restore the view after it.
  if saved and restored then
    vim.defer_fn(function()
      if vim.api.nvim_get_current_tabpage() ~= tab then return end
      local state = manager.get_state(saved.source, tab)
      if state.winid and vim.api.nvim_win_is_valid(state.winid) then
        local visible = manager.get_state_for_window(state.winid)
        if visible and visible.name == saved.source then
          vim.api.nvim_win_call(state.winid, function() vim.fn.winrestview(saved.view) end)
        end
      end
    end, 150)
  end
  if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
  if not restored then vim.notify(tostring(restore_err), vim.log.levels.ERROR) end
end

return M
