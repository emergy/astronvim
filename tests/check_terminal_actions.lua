-- nvim --headless -u NONE -i NONE -l tests/check_terminal_actions.lua
local root = vim.fn.getcwd()
vim.opt.rtp:prepend(root)
for _, name in ipairs { "toggleterm.nvim", "snacks.nvim" } do
  vim.opt.rtp:append(vim.fn.stdpath "data" .. "/lazy/" .. name)
end
require("snacks").setup { zen = { enabled = true } }
require("window_roles").setup()
local spec = dofile(root .. "/lua/plugins/toggleterm.lua")
local opts = { start_in_insert = false, persist_mode = false }
spec.opts(nil, opts)
require("toggleterm").setup(opts)
local actions, sessions = require "terminal_actions", require "terminal_sessions"
local function settle()
  vim.wait(120)
  vim.cmd.stopinsert()
end
local function count()
  return #vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative == "" end, vim.api.nvim_list_wins())
end
local function alive(term) return vim.fn.jobwait({ term.job_id }, 0)[1] == -1 end
local editor, file = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(file, 0, -1, false, { "unsaved editor" })
local horizontal = actions.split "horizontal"
settle()
assert(count() == 2 and vim.api.nvim_win_get_buf(horizontal) == file)
local vertical = actions.split "vertical"
settle()
assert(count() == 3 and vim.api.nvim_win_get_buf(vertical) == file)
actions.close_current()
settle()
assert(count() == 2 and vim.bo[file].modified)
vim.api.nvim_set_current_win(horizontal)
actions.close_current()
settle()
assert(count() == 1 and vim.api.nvim_win_is_valid(editor))

local first = sessions.new()
settle()
local base = first.window
local second = sessions.new()
settle()
assert(second.window == base and count() == 2)
actions.close_current()
settle()
assert(first.window == base and vim.api.nvim_win_get_buf(base) == first.bufnr)
assert(alive(first) and not alive(second), "closing current did not preserve the other shell")

local split = actions.split "horizontal"
settle()
assert(count() == 3 and split.window ~= base and alive(first) and alive(split))
assert(vim.api.nvim_win_get_buf(editor) == file, "terminal split replaced editor")
actions.close_current()
settle()
assert(count() == 2 and alive(first) and not alive(split))
sessions.activate(first)
if not require("terminal_zoom").active() then require("snacks").zen.zoom() end
local right = actions.split "vertical"
settle()
assert(count() == 3 and right.direction == "vertical" and alive(right) and alive(first))
local keep = sessions.new()
settle()
assert(keep.window == right.window or right.window == nil)
actions.close_all(true)
settle()
assert(#require("toggleterm.terminal").get_all() == 1 and alive(keep))
assert(not alive(first) and not alive(right), "close others left hidden or visible shells alive")
assert(vim.api.nvim_win_get_buf(editor) == file and vim.bo[file].modified)
actions.close_all(false)
settle()
assert(#require("toggleterm.terminal").get_all() == 0 and not alive(keep))
assert(count() == 1 and vim.api.nvim_win_get_buf(editor) == file and vim.bo[file].modified)
local auxiliary = require("toggleterm.terminal").Terminal:new { hidden = true, direction = "vertical", cmd = "cat" }
auxiliary:open()
settle()
vim.api.nvim_set_current_win(editor)
local regular = sessions.new()
settle()
actions.close_all(false)
settle()
assert(not alive(regular) and alive(auxiliary), "mass close affected an auxiliary terminal")
assert(vim.api.nvim_win_is_valid(auxiliary.window) and vim.bo[file].modified)
auxiliary:shutdown()
print "PASS: editor/PTY splits; current session close; geometry preserved; close others/all; unsaved file retained"
vim.cmd "qa!"
