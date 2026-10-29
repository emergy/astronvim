local root = vim.fn.getcwd()
vim.opt.rtp:append(root)
for _, plugin in ipairs { "plenary.nvim", "nui.nvim", "neo-tree.nvim", "hop.nvim" } do
  vim.opt.rtp:append(vim.fn.stdpath "data" .. "/lazy/" .. plugin)
end
vim.o.hidden = true
vim.o.columns = 120
vim.o.lines = 40
require("hop").setup {}
require("neo-tree").setup {
  sources = { "filesystem", "buffers", "git_status" },
  enable_git_status = false,
  enable_diagnostics = false,
  filesystem = { use_libuv_file_watcher = false },
  window = { width = 30 },
}
local command = require "neo-tree.command"
local manager = require "neo-tree.sources.manager"
local menu = require "buffer_menu"
local hop = require "hop"
local editor = vim.api.nvim_get_current_win()
local original = vim.fn.bufadd(root .. "/lua/plugins/astrocore.lua")
local target = vim.fn.bufadd(root .. "/lua/plugins/user.lua")
vim.fn.bufload(original)
vim.fn.bufload(target)
vim.bo[original].buflisted = true
vim.bo[target].buflisted = true
vim.api.nvim_win_set_buf(editor, original)
local errors = {}
vim.notify = function(msg, level)
  if level == vim.log.levels.ERROR then errors[#errors + 1] = msg end
end
local function visible()
  local found = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local state = manager.get_state_for_window(win)
    if state then found[#found + 1] = { source = state.name, width = vim.api.nvim_win_get_width(win), win = win } end
  end
  return found
end
local cancel = false
hop.hint_with_callback = function(generator, opts, callback)
  assert(vim.bo.filetype == "neo-tree", "picker must focus Neo-tree")
  local state = manager.get_state_for_window()
  assert(state.name == "buffers", "picker must use Bufs")
  assert(opts.multi_windows == false, "labels restricted to tree")
  local generated = generator()
  assert(#generated.jump_targets >= 2, "buffer nodes available")
  for _, jt in ipairs(generated.jump_targets) do
    local node = state.tree:get_node(jt.cursor.row)
    assert(node.extra and node.extra.bufnr, "directories must not have labels")
    if node.extra.bufnr == target and not cancel then
      callback(jt)
      return
    end
  end
  assert(cancel, "requested buffer must be visible")
end
for _, source in ipairs { "closed", "filesystem", "git_status", "buffers" } do
  for _, cancelled in ipairs { false, true } do
    command.execute { action = "close" }
    vim.api.nvim_set_current_win(editor)
    vim.api.nvim_win_set_buf(editor, original)
    if source ~= "closed" then
      command.execute { action = "show", source = source, position = "left" }
      vim.wait(250, function() return false end)
      local state = manager.get_state(source)
      vim.api.nvim_win_set_width(state.winid, 34)
    end
    vim.api.nvim_set_current_win(editor)
    local old_view
    if source ~= "closed" then
      local w = manager.get_state(source).winid
      vim.api.nvim_win_set_cursor(w, { math.min(3, vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(w))), 0 })
      old_view = vim.api.nvim_win_call(w, vim.fn.winsaveview)
    end
    local old_last = vim.deepcopy(command._last)
    cancel = cancelled
    menu.open()
    vim.wait(250, function() return false end)
    assert(#errors == 0, table.concat(errors, "\n"))
    local trees = visible()
    if source == "closed" then
      assert(#trees == 0, "initially hidden tree must close")
    else
      assert(#trees == 1 and trees[1].source == source, source .. ": source must restore")
      assert(trees[1].width == 34, "tree width must restore")
      local view = vim.api.nvim_win_call(trees[1].win, vim.fn.winsaveview)
      assert(view.lnum == old_view.lnum and view.topline == old_view.topline, "tree cursor/scroll must restore")
    end
    assert(vim.api.nvim_get_current_win() == editor, "focus must return to editor")
    assert(vim.api.nvim_win_get_buf(editor) == (cancelled and original or target), "selection/cancellation buffer")
    assert(vim.deep_equal(old_last, command._last), "last source must restore")
    print("PASS: " .. source .. (cancelled and " cancellation" or " selection"))
  end
end
-- Invocation from the tree must still open the selected file in the editor.
command.execute { action = "focus", source = "filesystem", position = "left" }
vim.wait(250, function() return false end)
cancel = false
menu.open()
vim.wait(250, function() return false end)
assert(vim.api.nvim_get_current_win() == editor, "selection from tree returns to editor")
assert(visible()[1].source == "filesystem", "File restored after invocation from tree")
print "PASS: invocation from tree"
vim.cmd "qa!"
