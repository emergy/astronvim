-- События ОС для загруженных файлов. Таймер используется только для объединения
-- пришедших событий; постоянного опроса файловой системы нет.
local M = {}
local uv = vim.uv or vim.loop
local buffers, directories, pending = {}, {}, {}
local timer, group, running, armed = nil, nil, false, false
local checks = 0

local function stamp(path)
  local stat = uv.fs_stat(path)
  if not stat then return end
  return table.concat({ stat.ino, stat.size, stat.mtime.sec, stat.mtime.nsec, stat.ctime.sec, stat.ctime.nsec }, ":")
end

local function eligible(buf)
  if not vim.api.nvim_buf_is_loaded(buf) then return false end
  local autoread = vim.bo[buf].autoread
  if autoread == nil then autoread = vim.go.autoread end
  return vim.bo[buf].buftype == "" and autoread and not vim.b[buf].ansible_vault
end

local function close(watch)
  watch:stop()
  if not watch:is_closing() then watch:close() end
end

local function forget(buf)
  local entry = buffers[buf]
  if not entry then return end
  for dir in pairs(entry.targets) do
    local watch = directories[dir]
    if watch then
      watch.buffers[buf] = nil
      if not next(watch.buffers) then
        directories[dir] = nil
        close(watch.handle)
      end
    end
  end
  buffers[buf], pending[buf] = nil, nil
end

local function conflict(entry, deleted)
  if entry.warned then return end
  entry.warned = true
  local reason = deleted and "Файл недоступен на диске; буфер сохранён: "
    or "Файл изменён извне; несохранённые правки сохранены: "
  vim.notify(reason .. vim.fn.fnamemodify(entry.path, ":~:."), vim.log.levels.WARN)
end

local queue
local function flush()
  armed = false
  if not running then return end
  if vim.fn.getcmdtype() ~= "" or vim.fn.getcmdwintype() ~= "" then return end
  local batch = pending
  pending = {}
  for buf, force in pairs(batch) do
    local entry = buffers[buf]
    if entry and eligible(buf) then
      local current = stamp(entry.path)
      if force or current ~= entry.stamp then
        local appeared = entry.stamp == nil and current ~= nil
        entry.stamp = current
        if not current then
          conflict(entry, true)
        elseif vim.bo[buf].modified then
          if not force then conflict(entry, false) end
        else
          checks = checks + 1
          -- Чтение выполняют штатные BufRead/FileType обработчики.
          local ok, err
          if appeared then
            -- Для BufNewFile checktime только предупреждает о появлении файла.
            -- Перечитываем его штатной командой без принудительного сброса правок.
            ok, err = pcall(vim.api.nvim_buf_call, buf, function() vim.cmd "edit" end)
          else
            ok, err = pcall(vim.cmd.checktime, buf)
          end
          if not ok then
            vim.notify("Не удалось обновить файл: " .. tostring(err), vim.log.levels.WARN)
          end
        end
      end
    end
  end
end

queue = function(buf, force)
  pending[buf] = pending[buf] or force or false
  if armed then return end
  armed = true
  timer:start(60, 0, vim.schedule_wrap(flush))
end

local function watch_directory(dir)
  if directories[dir] then return directories[dir] end
  local handle, creation_error = uv.new_fs_event()
  if not handle then
    vim.notify(
      "Не удалось наблюдать каталог " .. dir .. ": " .. tostring(creation_error),
      vim.log.levels.WARN
    )
    return
  end
  local watch = { handle = handle, buffers = {} }
  local ok, err = handle:start(dir, {}, function(event_error, filename)
    vim.schedule(function()
      if not running or directories[dir] ~= watch then return end
      if event_error then
        if not watch.warned then
          watch.warned = true
          vim.notify(
            "Наблюдение за каталогом " .. dir .. ": " .. tostring(event_error),
            vim.log.levels.WARN
          )
        end
        return
      end
      local name = filename and vim.fs.basename(filename)
      for buf, names in pairs(watch.buffers) do
        if not name or names[name] then queue(buf) end
      end
    end)
  end)
  if not ok then
    close(handle)
    vim.notify(
      "Не удалось наблюдать каталог " .. dir .. ": " .. tostring(err),
      vim.log.levels.WARN
    )
    return
  end
  directories[dir] = watch
  return watch
end

local function track(buf, initial, synced)
  if not eligible(buf) then
    forget(buf)
    return
  end
  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" or path:match "^%a[%w+.-]*://" then
    forget(buf)
    return
  end
  path = vim.fs.normalize(path)
  local targets = {}
  for _, target in ipairs { path, uv.fs_realpath(path) } do
    local dir, name = vim.fs.dirname(target), vim.fs.basename(target)
    if dir then
      targets[dir] = targets[dir] or {}
      targets[dir][name] = true
    end
  end
  local entry = buffers[buf]
  if entry and entry.path == path and vim.deep_equal(entry.targets, targets) then
    if synced then
      entry.stamp, entry.warned = stamp(path), nil
    end
    if initial and not vim.bo[buf].modified then queue(buf, true) end
    return
  end
  forget(buf)
  entry = { path = path, targets = targets, stamp = stamp(path) }
  buffers[buf] = entry
  for dir, names in pairs(targets) do
    local stat = uv.fs_stat(dir)
    if stat and stat.type == "directory" then
      local watch = watch_directory(dir)
      if watch then watch.buffers[buf] = names end
    end
  end
  if initial and not vim.bo[buf].modified then queue(buf, true) end
end

function M.stats()
  return { buffers = vim.tbl_count(buffers), directories = vim.tbl_count(directories), checks = checks }
end

function M.stop()
  running, armed = false, false
  if timer then
    close(timer)
    timer = nil
  end
  for _, watch in pairs(directories) do
    close(watch.handle)
  end
  buffers, directories, pending = {}, {}, {}
  if group then
    vim.api.nvim_del_augroup_by_id(group)
    group = nil
  end
end

function M.setup()
  if running then return end
  running = true
  timer = assert(uv.new_timer())
  group = vim.api.nvim_create_augroup("NativeFileWatch", { clear = true })
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
    group = group,
    callback = function(args) track(args.buf, false, true) end,
  })
  vim.api.nvim_create_autocmd(
    { "BufNewFile", "BufFilePost" },
    { group = group, callback = function(args) track(args.buf) end }
  )
  vim.api.nvim_create_autocmd({ "BufUnload", "BufWipeout" }, {
    group = group,
    callback = function(args) forget(args.buf) end,
  })
  vim.api.nvim_create_autocmd("OptionSet", {
    group = group,
    pattern = { "autoread", "buftype" },
    callback = function()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        track(buf, true)
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "CmdlineLeave", "CmdwinLeave" }, {
    group = group,
    callback = function()
      if next(pending) then
        local buf = next(pending)
        queue(buf, pending[buf])
      end
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", { group = group, once = true, callback = M.stop })
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    track(buf, true)
  end
end

return M
