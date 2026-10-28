local config = vim.fn.stdpath "config"
vim.opt.runtimepath:prepend(vim.fn.stdpath "data" .. "/lazy/toggleterm.nvim")
local core = dofile(config .. "/lua/plugins/astrocore.lua")
vim.opt.scrollback = core.opts.options.opt.scrollback
assert(vim.o.scrollback == 100000)
package.loaded.terminal_sessions = { setup = function() end, label = function() return "test" end }
local spec = dofile(config .. "/lua/plugins/toggleterm.lua")
local opts = { start_in_insert = false, winbar = { enabled = false } }
spec.opts(nil, opts)
assert(opts.auto_scroll == false)
opts.winbar.enabled = false
require("toggleterm").setup(opts)
local python = "import sys,tty\ntty.setraw(0)\ni=0\nfor command in sys.stdin:\n n=int(command)\n for _ in range(n):\n  i+=1\n  sys.stdout.write('line-%d\\r\\n'%i)\n sys.stdout.flush()\n"
local term = require("toggleterm.terminal").Terminal:new {
  cmd = "python3 -u -c " .. vim.fn.shellescape(python),
  direction = "horizontal",
}
term:open()
vim.cmd.stopinsert()
assert(term.auto_scroll == false)
assert(vim.bo[term.bufnr].scrollback == 100000)
local function output(n, marker)
  vim.api.nvim_chan_send(term.job_id, tostring(n) .. "\n")
  assert(vim.wait(10000, function()
    return table.concat(vim.api.nvim_buf_get_lines(term.bufnr, -30, -1, false), "\n"):find(marker, 1, true) ~= nil
  end, 10), "terminal output timeout: " .. marker)
  vim.wait(100)
end
-- Give the subprocess time to disable PTY echo before sending commands.
vim.wait(250)
output(12000, "line-12000")
assert(vim.api.nvim_buf_line_count(term.bufnr) > 10000, "history truncated at old default")
local win = term.window
vim.api.nvim_win_set_cursor(win, { 100, 0 })
vim.cmd "normal! zt"
local before = vim.fn.winsaveview()
output(20, "line-12020")
local after = vim.fn.winsaveview()
assert(after.lnum == before.lnum and after.topline == before.topline, "output moved scrolled-back view")
vim.cmd "normal! G"
output(20, "line-12040")
assert(vim.api.nvim_win_get_cursor(win)[1] == vim.api.nvim_buf_line_count(term.bufnr), "following did not resume at bottom")
vim.fn.jobstop(term.job_id)
print("PASS: 100000-line history; retained >10000 lines; scrolled view stays put; following resumes at bottom")
