-- Изолированная проверка настоящих ToggleTerm PTY и окон Snacks Zoom.
-- nvim --headless -u NONE -i NONE -l tests/check_terminal_panels.lua
local root = vim.fn.getcwd()
vim.opt.rtp:prepend(root)
for _, name in ipairs { "toggleterm.nvim", "snacks.nvim", "codex.nvim" } do
  vim.opt.rtp:append(vim.fn.stdpath "data" .. "/lazy/" .. name)
end
require("snacks").setup { zen = { enabled = true } }
local roles = require "window_roles"
roles.setup()
local spec = dofile(root .. "/lua/plugins/toggleterm.lua")
local opts = { start_in_insert = false, persist_mode = false }
spec.opts(nil, opts)
require("toggleterm").setup(opts)
local sessions = require "terminal_sessions"
local zoom = require "terminal_zoom"
local editor = vim.api.nvim_get_current_win()
local file1 = vim.api.nvim_get_current_buf()
local file2 = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(file1, 0, -1, false, { "editor one" })
vim.api.nvim_buf_set_lines(file2, 0, -1, false, { "editor two" })
local function settle()
  vim.wait(100)
  vim.cmd.stopinsert()
end
local function splits()
  return vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative == "" end, vim.api.nvim_list_wins())
end
local function intact(term, base)
  settle()
  assert(#splits() == 2, "unexpected terminal split")
  assert(vim.api.nvim_win_get_buf(editor) == file1, "editor became a terminal")
  assert(
    term.window == base and vim.api.nvim_win_get_buf(base) == term.bufnr,
    "lost terminal owner: "
      .. vim.inspect { owner = term.window, base = base, actual = vim.api.nvim_win_get_buf(base), buf = term.bufnr }
  )
end
local first = sessions.new()
settle()
local base = first.window
intact(first, base)
local first_job = first.job_id
local second = sessions.new()
intact(second, base)
assert(first.window == nil and first_job == first.job_id, "new session destroyed the old shell")
local second_job = second.job_id
if not zoom.active(second.bufnr) then require("snacks").zen.zoom { zoom = { win = { height = 0 } } } end
settle()
assert(zoom.active(second.bufnr), "zoom did not open")
local selected = first
vim.ui.select = function(_, _, callback) callback(selected) end
for index = 1, 20 do
  selected = index % 2 == 1 and first or second
  sessions.select()
  intact(selected, base)
  assert(zoom.active(selected.bufnr), "F8 lost zoom")
  assert(vim.api.nvim_get_current_buf() == selected.bufnr, "wrong active session")
end
selected = nil
local before = vim.api.nvim_get_current_win()
sessions.select()
assert(vim.api.nvim_get_current_win() == before and zoom.active(second.bufnr), "cancel changed the terminal")
assert(
  require("toggleterm.ui").winbar(second.id):find("v:lua.NvimTerminalSessionClick", 1, true),
  "old winbar callback"
)
for _, term in ipairs { first, second, first, first, second } do
  _G.NvimTerminalSessionClick(term.id, 1, "l", "")
  intact(term, base)
  assert(zoom.active(term.bufnr), "winbar click lost zoom")
end

-- Настоящий пользовательский обработчик таббара, без подмены исходников плагина.
local component =
  { on_click = { name = "heirline_tabline_buffer_callback", callback = function() error "old callback" end } }
require("buffer_mouse").patch_tabline(component)
component.on_click.callback({}, first.bufnr, 1, "l", "")
intact(first, base)
assert(zoom.active(first.bufnr), "terminal click lost zoom")
component.on_click.callback({}, file2, 1, "l", "")
settle()
assert(vim.api.nvim_get_current_win() == editor and vim.api.nvim_win_get_buf(editor) == file2)
assert(vim.api.nvim_win_get_buf(base) == first.bufnr and not zoom.active(), "file click replaced terminal")
file1 = file2
component.on_click.callback({}, second.bufnr, 1, "l", "")
intact(second, base)
assert(vim.api.nvim_get_current_buf() == second.bufnr, "terminal click stayed in editor")

-- Общая защита для :buffer, сторонних pickers и других путей открытия.
vim.api.nvim_set_current_win(editor)
vim.api.nvim_win_set_buf(editor, first.bufnr)
intact(first, base)
assert(vim.api.nvim_get_current_buf() == first.bufnr, "terminal was not redirected")
vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), file2)
intact(first, base)
assert(vim.api.nvim_get_current_win() == editor, "file was not redirected: " .. vim.inspect {
  current = vim.api.nvim_get_current_win(),
  editor = editor,
  zoom = zoom.active(),
  buf = vim.api.nvim_get_current_buf(),
})

-- F7 в zoom должен скрывать один терминальный split, а затем вернуть один.
vim.api.nvim_set_current_win(base)
if not zoom.active(first.bufnr) then require("snacks").zen.zoom { zoom = { win = { height = 0 } } } end
settle()
require("toggleterm").toggle()
settle()
assert(#splits() == 1 and not zoom.active(), "toggle left a duplicate or a zoom")
require("toggleterm").toggle()
settle()
assert(#splits() == 2, "toggle reopened duplicate terminals")
assert(vim.api.nvim_win_get_buf(editor) == file1, "toggle replaced editor")
assert(first.job_id == first_job and second.job_id == second_job, "switch restarted a shell")
assert(vim.fn.jobwait({ first_job, second_job }, 0)[1] == -1, "first shell died")
assert(vim.fn.jobwait({ first_job, second_job }, 0)[2] == -1, "second shell died")

-- Служебный терминал (как отдельная панель Codex) не заимствует обычную панель.
vim.api.nvim_set_current_win(editor)
settle()
local hidden = require("toggleterm.terminal").Terminal:new { hidden = true, direction = "vertical", cmd = "cat" }
hidden:open()
settle()
local hidden_window = hidden.window
sessions.activate(first)
roles.open(hidden.bufnr)
settle()
assert(vim.api.nvim_get_current_win() == hidden_window, "service terminal duplicated into another panel")
assert(vim.api.nvim_win_get_buf(hidden_window) == hidden.bufnr)
hidden:shutdown()
settle()

-- Настоящий установленный модуль Codex; вместо Codex CLI работает cat.
local codex = require "codex"
codex.setup { panel = true, width = 0.33, autoinstall = false, cmd = { "cat" } }
vim.api.nvim_set_current_win(editor)
codex.open()
settle()
local codex_state = require "codex.state"
local codex_window, codex_buffer, codex_job = codex_state.win, codex_state.buf, codex_state.job
assert(vim.bo[codex_buffer].buftype == "terminal" and vim.api.nvim_win_get_buf(editor) == file1)
roles.open(file1)
settle()
assert(vim.api.nvim_get_current_win() == editor and vim.api.nvim_win_get_buf(codex_window) == codex_buffer)
roles.open(codex_buffer)
settle()
assert(vim.api.nvim_get_current_win() == codex_window and codex_state.job == codex_job)
codex.close()
vim.fn.jobstop(codex_job)
settle()

-- Даже преобразование пустого редакторского буфера через :terminal остаётся
-- отдельной панелью, а не меняет назначение исходного окна.
vim.cmd.tabnew()
vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))
settle()
local empty_editor = vim.api.nvim_get_current_win()
local raw_job = vim.fn.termopen { "cat" }
settle()
assert(vim.bo[vim.api.nvim_win_get_buf(empty_editor)].buftype ~= "terminal", ":terminal replaced an editor")
assert(vim.api.nvim_get_current_win() ~= empty_editor and vim.bo.buftype == "terminal", "raw PTY not redirected")
vim.fn.jobstop(raw_job)
for _, term in ipairs { first, second } do
  vim.fn.jobstop(term.job_id)
end
print "PASS: native PTY sessions; new session; 20 zoom switches; tabbar routing; window roles; F7; shells preserved"
vim.cmd "qa!"
