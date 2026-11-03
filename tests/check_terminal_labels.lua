vim.opt.runtimepath:prepend(vim.fn.getcwd())
local context = require "terminal_context"
local sessions = require "terminal_sessions"
local root = vim.fn.getcwd() .. "/.tmp/terminal-labels-" .. (vim.uv or vim.loop).os_getpid()
local first, second = root .. "/first % dir", root .. "/second % dir"
vim.fn.mkdir(first, "p", 448)
vim.fn.mkdir(second, "p", 448)
local original_cwd = vim.fn.getcwd()
local terms = {}
package.loaded["toggleterm.terminal"] = { get_all = function() return terms end }
local jobs = {}
local function terminal(command, directory, id)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  local job = vim.fn.termopen(command, { cwd = directory })
  jobs[#jobs + 1] = job
  local term = { id = id, bufnr = buf, job_id = job, dir = directory }
  terms[#terms + 1] = term
  return term
end
local function wait(predicate, description) assert(vim.wait(5000, predicate, 20), description) end
local ok, err = pcall(function()
  local shell = terminal({ "bash", "--noprofile", "--norc" }, first, 1)
  wait(function() return context.inspect(shell).cwd == first end, "shell directory")
  vim.api.nvim_chan_send(shell.job_id, "cd -- " .. vim.fn.shellescape(second) .. "\n")
  wait(function() return context.inspect(shell).cwd == second end, "directory must follow cd")
  sessions.refresh()
  assert(
    sessions.label(shell):find(vim.fn.fnamemodify(second, ":~"), 1, true),
    "picker must include full live directory"
  )
  assert(not sessions.label(shell, true):find(root, 1, true), "winbar must use compact directory")
  shell.display_name = "Deploy API"
  sessions.refresh()
  assert(sessions.label(shell):find("Deploy API", 1, true), "preserve explicit session name")

  local fake =
    "import sys,time; sys.stdout.write('\\x1b]2;tester@remote.example:/srv/remote\\x07'); sys.stdout.flush(); time.sleep(30)"
  -- A local fake SSH process; no network connections or authentication.
  local ssh = terminal({
    "bash",
    "-c",
    "exec -a ssh python3 -c "
      .. vim.fn.shellescape(fake)
      .. " -v -J jump -p 2222 -l tester -- remote.example not-for-label",
  }, first, 2)
  wait(
    function()
      return context.inspect(ssh).destination == "tester@remote.example:2222"
        and (vim.b[ssh.bufnr].term_title or ""):find("/srv/remote", 1, true) ~= nil
    end,
    "SSH destination and remote shell title"
  )
  sessions.refresh()
  local label = sessions.label(ssh)
  assert(label:find("tester@remote.example:2222", 1, true), "SSH destination")
  assert(
    label:find("/srv/remote", 1, true) and label:find(vim.fn.fnamemodify(first, ":~"), 1, true),
    "remote and local directories"
  )
  assert(not label:find("not-for-label", 1, true), "do not display the remote command")
  vim.b[ssh.bufnr].term_title = "tester@" .. (vim.uv or vim.loop).os_gethostname() .. ": /stale/local"
  sessions.refresh()
  assert(not sessions.label(ssh):find("/stale/local", 1, true), "ignore stale local title in SSH")
  assert(sessions.label(ssh):find("локально:", 1, true), "distinguish unknown remote directory from local cwd")

  for _, args in ipairs {
    { { "ssh", "-o", "User=tester", "-oPort=2222", "-i", "key file", "host", "secret" }, "tester@host:2222" },
    { { "ssh", "-vvv", "-Jjump", "user@host", "secret" }, "user@host" },
    { { "ssh", "ssh://user@host:2222", "secret" }, "ssh://user@host:2222" },
  } do
    assert(context.ssh_destination(args[1]) == args[2], "SSH option parsing")
  end
  local opts = {}
  dofile("lua/plugins/toggleterm.lua").opts(nil, opts)
  local rendered = vim.api.nvim_eval_statusline(opts.winbar.name_formatter(shell), { use_winbar = true }).str
  assert(rendered == sessions.label(shell, true), "escape percent signs in winbar")
  local titlestring = dofile("lua/plugins/astrocore.lua").opts.options.opt.titlestring
  local title = vim.api.nvim_eval_statusline(titlestring, { maxwidth = 4096 }).str
  assert(title:find("ssh", 1, true) and not title:find("#toggleterm#", 1, true), "friendly terminal title: " .. title)
  local normal = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(normal)
  vim.api.nvim_buf_set_name(normal, root .. "/normal.lua")
  assert(sessions.title():find("normal.lua [", 1, true), "preserve normal file title")
  assert(vim.fn.getcwd() == original_cwd, "metadata must not change Neovim workdir")
  for _, job in ipairs(jobs) do
    assert(vim.fn.jobwait({ job }, 0)[1] == -1, "metadata must not interrupt jobs")
  end
end)
for _, job in ipairs(jobs) do
  pcall(vim.fn.jobstop, job)
end
if not ok then error(err) end
print "PASS: live cwd, SSH destination/options, remote title fallback, safe labels/winbar/title, jobs preserved"
