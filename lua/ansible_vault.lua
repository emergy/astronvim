local M = {}
local uv = vim.uv or vim.loop
local states = {}
local group

local function read(path)
  local file, err = io.open(path, "rb")
  if not file then return nil, err end
  local data = file:read "*a"
  file:close()
  return data
end

local function is_vault(data) return data and data:match "^%$ANSIBLE_VAULT;[^\r\n]+[\r\n]" ~= nil end

local function protect(buf)
  vim.bo[buf].swapfile = false
  vim.bo[buf].undofile = false
  vim.bo[buf].modeline = false
  vim.bo[buf].buftype = "acwrite"
  vim.b[buf].ansible_vault = true
end

local function crypto(action, data, state)
  if vim.fn.executable "ansible-vault" == 0 then return nil, "ansible-vault не найден в PATH" end
  local ok, result = pcall(function()
    local args = { "ansible-vault", action, "--output", "-" }
    -- Keep the label from the file; passwords and identities are resolved by Ansible.
    if action == "encrypt" and state.identity then vim.list_extend(args, { "--encrypt-vault-id", state.identity }) end
    args[#args + 1] = "-"
    return vim.system(args, { stdin = data, cwd = state.cwd, timeout = 30000 }):wait()
  end)
  if not ok then return nil, "не удалось запустить ansible-vault" end
  if result.code ~= 0 then
    return nil,
      vim.trim(result.stderr or "") ~= "" and vim.trim(result.stderr)
        or "ansible-vault завершился с ошибкой"
  end
  return result.stdout
end

-- Only ciphertext is ever written to this temporary file, alongside the destination.
local function replace(path, ciphertext, state)
  if uv.fs_realpath(path) ~= state.realpath then
    return nil, "путь файла изменился; перечитайте его через :edit!"
  end
  local current, err = read(state.realpath)
  if not current then return nil, err end
  if current ~= state.ciphertext then
    return nil, "файл изменён другим процессом; сохранение отменено"
  end
  local stat = uv.fs_stat(state.realpath)
  if not stat or stat.type ~= "file" or vim.fn.filewritable(state.realpath) ~= 1 then
    return nil, "файл недоступен для записи"
  end
  if stat.nlink > 1 then
    return nil,
      "атомарная запись файла с жёсткими ссылками не поддерживается"
  end
  if stat.uid ~= uv.getuid() then
    return nil,
      "сохранение от имени другого владельца не поддерживается"
  end
  local fd, temporary = uv.fs_mkstemp(vim.fs.dirname(state.realpath) .. "/.nvim-vault-XXXXXX")
  if not fd then return nil, temporary end
  local ok, failure = pcall(function()
    assert(uv.fs_fchmod(fd, bit.band(stat.mode, 511)))
    assert(uv.fs_fchown(fd, stat.uid, stat.gid))
    local offset = 0
    while offset < #ciphertext do
      local written = assert(uv.fs_write(fd, ciphertext:sub(offset + 1), offset))
      assert(written > 0, "неполная запись шифротекста")
      offset = offset + written
    end
    assert(uv.fs_fsync(fd))
    assert(uv.fs_close(fd))
    fd = nil
    local latest = read(state.realpath)
    assert(
      latest == state.ciphertext,
      "файл изменён другим процессом; сохранение отменено"
    )
    assert(uv.fs_rename(temporary, state.realpath))
  end)
  if fd then uv.fs_close(fd) end
  if not ok then
    uv.fs_unlink(temporary)
    return nil, tostring(failure)
  end
  state.ciphertext = ciphertext
  state.identity = ciphertext:match "^%$ANSIBLE_VAULT;[^;\r\n]+;[^;\r\n]+;([^\r\n]+)"
  return true
end

function M.write(buf, target, event)
  local state = states[buf]
  if not state or not state.decrypted then
    error("Vault: файл не расшифрован; запись запрещена", 0)
  end
  if event ~= "BufWriteCmd" or vim.fn.fnamemodify(target, ":p") ~= state.path then
    error(
      "Vault: поддерживается только :write в исходный файл, без диапазона и дописывания",
      0
    )
  end
  if vim.bo[buf].readonly then error("Vault: файл открыт только для чтения", 0) end
  protect(buf)
  local separator = vim.bo[buf].fileformat == "dos" and "\r\n" or "\n"
  local plaintext = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), separator)
  if vim.bo[buf].endofline then plaintext = plaintext .. separator end
  if vim.bo[buf].bomb then plaintext = "\239\187\191" .. plaintext end
  local readable, credential_error = crypto("decrypt", state.ciphertext, state)
  if not readable then error("Vault: " .. credential_error, 0) end
  local ciphertext, err = crypto("encrypt", plaintext, state)
  if not ciphertext then error("Vault: " .. err, 0) end
  if not is_vault(ciphertext) then
    error("Vault: ansible-vault не вернул шифротекст; файл не изменён", 0)
  end
  local ok, failure = replace(state.path, ciphertext, state)
  if not ok then error("Vault: " .. failure, 0) end
  vim.bo[buf].modified = false
  vim.api.nvim_exec_autocmds("BufWritePost", { buffer = buf, modeline = false })
end

local function before_read(event)
  local path = vim.fn.fnamemodify(event.file, ":p")
  local stat = uv.fs_stat(path)
  if not stat or stat.type ~= "file" then return end
  local file = io.open(path, "rb")
  if not file then return end
  local header = file:read(256)
  file:close()
  if not is_vault(header) then
    if states[event.buf] then
      states[event.buf].decrypted = false
      states[event.buf].read_error = "файл больше не содержит заголовок Ansible Vault"
    end
    return
  end
  local ciphertext = read(path)
  if not ciphertext then return end
  if not states[event.buf] then
    vim.api.nvim_create_autocmd({ "BufWriteCmd", "FileWriteCmd", "FileAppendCmd" }, {
      group = group,
      buffer = event.buf,
      callback = function(args) M.write(args.buf, args.match, args.event) end,
    })
  end
  local previous = states[event.buf]
  local readonly, modifiable = vim.bo[event.buf].readonly, vim.bo[event.buf].modifiable
  if previous then
    readonly, modifiable = previous.readonly, previous.modifiable
  end
  states[event.buf] = {
    path = path,
    realpath = uv.fs_realpath(path),
    ciphertext = ciphertext,
    cwd = vim.fn.getcwd(),
    readonly = readonly,
    modifiable = modifiable,
    identity = ciphertext:match "^%$ANSIBLE_VAULT;[^;\r\n]+;[^;\r\n]+;([^\r\n]+)",
  }
  vim.bo[event.buf].modifiable = modifiable
  protect(event.buf)
end

local function after_read(event)
  local state = states[event.buf]
  if not state then return end
  protect(event.buf)
  local plaintext, err
  if state.read_error then
    err = state.read_error
  else
    plaintext, err = crypto("decrypt", state.ciphertext, state)
  end
  if plaintext and plaintext:find("\0", 1, true) then
    plaintext, err = nil, "двоичные Vault-файлы не поддерживаются"
  end
  if not plaintext then
    vim.bo[event.buf].readonly = true
    vim.bo[event.buf].modifiable = false
    vim.notify("Vault: " .. err, vim.log.levels.ERROR)
    return
  end
  local bom = plaintext:sub(1, 3) == "\239\187\191"
  if bom then plaintext = plaintext:sub(4) end
  local dos = plaintext:find("\r\n", 1, true) ~= nil and not plaintext:gsub("\r\n", ""):find("\n", 1, true)
  if dos then plaintext = plaintext:gsub("\r\n", "\n") end
  local eol = plaintext:sub(-1) == "\n"
  if eol then plaintext = plaintext:sub(1, -2) end
  vim.bo[event.buf].modifiable = true
  vim.bo[event.buf].readonly = state.readonly or vim.fn.filewritable(state.path) ~= 1
  -- Drop the initial encrypted undo state; persistent undo remains disabled.
  local undo = vim.bo[event.buf].undolevels
  vim.bo[event.buf].undolevels = -1
  vim.api.nvim_buf_set_lines(event.buf, 0, -1, false, vim.split(plaintext, "\n", { plain = true }))
  vim.bo[event.buf].undolevels = undo
  vim.bo[event.buf].fileformat = dos and "dos" or "unix"
  vim.bo[event.buf].bomb = bom
  vim.bo[event.buf].endofline = eol
  vim.bo[event.buf].fixendofline = false
  vim.bo[event.buf].modified = false
  state.decrypted = true
  vim.bo[event.buf].modifiable = state.modifiable
  vim.bo[event.buf].filetype = vim.filetype.match { buf = event.buf, filename = state.path } or "yaml"
end

function M.setup()
  if group then return end
  group = vim.api.nvim_create_augroup("UserAnsibleVault", { clear = true })
  vim.api.nvim_create_autocmd("BufReadPre", { group = group, callback = before_read })
  vim.api.nvim_create_autocmd("BufReadPost", { group = group, callback = after_read })
  vim.api.nvim_create_autocmd("BufWipeout", { group = group, callback = function(event) states[event.buf] = nil end })
end

return M
