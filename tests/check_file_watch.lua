-- Реальные fs_event/inotify, без установки плагинов и без изменения пользовательских файлов.
-- nvim --headless -u NONE -i NONE -l tests/check_file_watch.lua
local root = vim.fn.getcwd()
vim.opt.rtp:prepend(root)
vim.o.autoread, vim.o.hidden = true, true
local uv = vim.uv or vim.loop
local scratch = root .. "/.tmp/file-watch-" .. tostring(uv.hrtime())
vim.fn.mkdir(scratch .. "/target", "p")
local function write(path, text) vim.fn.writefile({ text }, path) end
local function text(buf) return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") end
local function wait_for(predicate, message) assert(vim.wait(3000, predicate, 10), message) end
local warnings = {}
vim.notify = function(message) warnings[#warnings + 1] = message end
local watch = require "file_watch"
watch.setup()
write(scratch .. "/one", "one")
write(scratch .. "/two", "two")
vim.cmd.edit(scratch .. "/one")
local one = vim.api.nvim_get_current_buf()
vim.cmd.edit(scratch .. "/two")
local two = vim.api.nvim_get_current_buf()
assert(
  watch.stats().directories == 1 and watch.stats().buffers == 2,
  "one watcher per directory: " .. vim.inspect(watch.stats())
)
write(scratch .. "/one", "changed hidden file")
wait_for(function() return text(one) == "changed hidden file" end, "hidden file not reloaded")
assert(vim.api.nvim_get_current_buf() == two, "reload changed focus")
write(scratch .. "/replacement", "atomic replacement")
assert(uv.fs_rename(scratch .. "/replacement", scratch .. "/one"))
wait_for(function() return text(one) == "atomic replacement" end, "atomic save broke watcher")
write(scratch .. "/one", "write after atomic save")
wait_for(function() return text(one) == "write after atomic save" end, "watcher followed the old inode")
vim.wait(100)
local checks = watch.stats().checks
write(scratch .. "/unrelated", "not a loaded buffer")
vim.wait(200)
assert(watch.stats().checks == checks, "unrelated event caused a file scan")
vim.wait(200)
assert(watch.stats().checks == checks, "idle polling detected")

vim.api.nvim_buf_set_lines(one, 0, -1, false, { "unsaved local edits" })
write(scratch .. "/one", "external conflict")
wait_for(function() return #warnings == 1 end, "conflict was not reported")
assert(text(one) == "unsaved local edits" and vim.bo[one].modified, "local edits were overwritten")
write(scratch .. "/one", "another external conflict")
vim.wait(150)
assert(#warnings == 1, "repeated conflict notification")
-- Явная команда пользователя разрешает конфликт; watcher не выполняет edit!.
vim.api.nvim_buf_call(one, function() vim.cmd "edit!" end)
write(scratch .. "/one", "watch after conflict resolution")
wait_for(function() return text(one) == "watch after conflict resolution" end, "conflict resolution disabled watcher")

local target = scratch .. "/target/file"
write(target, "symlink target")
assert(uv.fs_symlink(target, scratch .. "/link"))
vim.cmd.edit(scratch .. "/link")
local link = vim.api.nvim_get_current_buf()
write(target, "changed via target path")
wait_for(function() return text(link) == "changed via target path" end, "symlink target was not watched")
assert(watch.stats().directories == 2, "symlink target directory missing")

vim.cmd.edit(scratch .. "/new-file")
local new = vim.api.nvim_get_current_buf()
write(scratch .. "/new-file", "created by another process")
wait_for(function() return text(new) == "created by another process" end, "new file not detected")
assert(uv.fs_unlink(scratch .. "/new-file"))
wait_for(function() return #warnings == 2 end, "deletion was not reported")
assert(text(new) == "created by another process", "deletion discarded buffer")
write(scratch .. "/new-file", "recreated")
wait_for(function() return text(new) == "recreated" end, "recreation not detected")
vim.bo[one].autoread = false
write(scratch .. "/one", "autoread disabled")
vim.wait(150)
assert(text(one) == "watch after conflict resolution", "local noautoread was ignored")
vim.bo[one].autoread = true
wait_for(function() return text(one) == "autoread disabled" end, "reenabling autoread did not catch up")

watch.stop()
write(scratch .. "/two", "changed before setup")
watch.setup()
wait_for(function() return text(two) == "changed before setup" end, "already loaded buffer was not caught up")

-- Файлы с пользовательским обработчиком, включая Vault, не перечитываются.
local special = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(special, scratch .. "/vault")
vim.bo[special].buftype = "acwrite"
vim.b[special].ansible_vault = true
vim.api.nvim_exec_autocmds("BufReadPost", { buffer = special })
assert(watch.stats().buffers == 4, "custom-read buffer was watched")
for _, buf in ipairs { one, two, link, new, special } do
  vim.api.nvim_buf_delete(buf, { force = true })
end
assert(watch.stats().directories == 0 and watch.stats().buffers == 0, "watcher handles leaked")
watch.stop()
print "PASS: native events; hidden reload; atomic save; no idle/unrelated polling; conflicts; symlinks; create/delete/recreate; autoread; initial sync; Vault exclusion; cleanup"
vim.cmd "qa!"
