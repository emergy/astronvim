-- nvim --headless -u NONE -i NONE -l tests/check_terminal_shortcuts.lua
local root = vim.fn.getcwd()
vim.opt.rtp:prepend(root)
for _, name in ipairs { "toggleterm.nvim", "snacks.nvim" } do
  vim.opt.rtp:append(vim.fn.stdpath "data" .. "/lazy/" .. name)
end
require("snacks").setup { zen = { enabled = true } }
require("window_roles").setup()
local spec = dofile(root .. "/lua/plugins/toggleterm.lua")
local opts = { shell = "cat", start_in_insert = false, persist_mode = false }
spec.opts(nil, opts)
require("toggleterm").setup(opts)
local sessions = require "terminal_sessions"
local term_api = require "toggleterm.terminal"
local function settle()
  vim.wait(100)
  vim.cmd.stopinsert()
end
local first = sessions.new { id = 1 }
settle()
local base = first.window
local third = sessions.new { id = 3 }
settle()
local tenth = sessions.new { id = 10 }
settle()
local auxiliary = term_api.Terminal:new { id = 2, hidden = true, direction = "horizontal" }
auxiliary:spawn()
if not require("terminal_zoom").active() then require("snacks").zen.zoom() end
local function selected(term)
  settle()
  assert(vim.api.nvim_get_current_buf() == term.bufnr and term.window == base)
  assert(require("terminal_zoom").active(term.bufnr), "shortcut lost zoom")
  assert(
    #vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative == "" end, vim.api.nvim_list_wins()) == 2
  )
end
sessions.by_id(1)
selected(first)
sessions.cycle(-1)
selected(tenth)
sessions.cycle(1)
selected(first)
sessions.cycle(1)
selected(third)
local count = #term_api.get_all()
sessions.by_id(2)
sessions.by_id(9)
assert(#term_api.get_all() == count and vim.api.nvim_get_current_buf() == third.bufnr, "missing ID created a session")

-- Проверка конкретных цифр, в том числе 0 -> 10, и алиаса меню F8.
local keys = {}
for _, mapping in ipairs(spec.keys()) do
  keys[mapping[1]] = mapping[2]
end
keys["<Leader>0"]()
selected(tenth)
keys["<Leader>1"]()
selected(first)
vim.ui.select = function(_, _, callback) callback(third) end
keys["<Leader>tT"]()
selected(third)

-- Настоящая интерактивная Bash-функция, без запуска Docker/devcontainer CLI.
local scratch = root .. "/.tmp/terminal shortcuts-" .. tostring(vim.uv.hrtime())
vim.fn.mkdir(scratch, "p")
local marker, rc = scratch .. "/called.txt", scratch .. "/bashrc"
vim.fn.writefile(
  { 'd-c() { printf \'%s\\n\' "$PWD" "$*" > ' .. vim.fn.shellescape(marker) .. "; }", "PS1='test$ '" },
  rc
)
require("toggleterm.config").set { shell = "bash --noprofile --rcfile " .. vim.fn.shellescape(rc) .. " -i" }
vim.cmd.tcd(scratch)
local dev = require("terminal_actions").devcontainer()
assert(
  vim.wait(
    5000,
    function() return vim.fn.filereadable(marker) == 1 and vim.deep_equal(vim.fn.readfile(marker), { scratch, "up" }) end,
    20
  ),
  "wrong command or workspace directory"
)
selected(dev)
assert(dev ~= first and dev ~= third and dev ~= tenth and dev ~= auxiliary)
for _, term in ipairs { first, third, tenth, auxiliary } do
  assert(vim.fn.jobwait({ term.job_id }, 0)[1] == -1, "existing terminal was replaced")
end
for _, term in ipairs(term_api.get_all(true)) do
  vim.fn.jobstop(term.job_id)
end
print "PASS: terminal IDs including 10; gap/auxiliary exclusion; cyclic navigation; zoom/geometry; menu alias; d-c shell function and cwd"
vim.cmd "qa!"
