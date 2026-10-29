vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.scrollback = 100000
local job = vim.fn.termopen {
  "python3",
  "-u",
  "-c",
  "import sys\nprint('history\\n'*2000, flush=True)\nfor line in sys.stdin: print('still-alive', flush=True)",
}
local buf = vim.api.nvim_get_current_buf()
assert(vim.wait(5000, function() return vim.api.nvim_buf_line_count(buf) > 1000 end, 10), "history not ready")
local history = require "terminal_history"
history.clear()
history.clear()
-- Restore the captured buffer, even if focus changes during the deferred callback.
local other = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(other)
local original = vim.bo[other].scrollback
assert(
  vim.wait(2000, function() return vim.api.nvim_buf_line_count(buf) < 100 and vim.bo[buf].scrollback == 100000 end, 10),
  "history not cleared or limit not restored"
)
assert(vim.bo[other].scrollback == original, "reset changed another buffer")
assert(vim.fn.jobwait({ job }, 0)[1] == -1, "terminal process stopped")
vim.api.nvim_chan_send(job, "ping\n")
assert(
  vim.wait(
    2000,
    function()
      return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"):find("still-alive", 1, true) ~= nil
    end,
    10
  ),
  "process no longer responds"
)
vim.fn.jobstop(job)
print "PASS: terminal history cleared, repeated clear and focus change safe, limit restored, process responds"
