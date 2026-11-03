local M = {}
local uv = vim.uv or vim.loop

local function clean(value) return (value or ""):gsub("[%c]", " ") end

local function read(path)
  local file = io.open(path, "rb")
  if not file then return end
  local contents = file:read(65536)
  file:close()
  return contents
end

local function basename(path) return vim.fn.fnamemodify(path or "", ":t"):gsub("%.exe$", "") end

-- Read only the SSH destination/options needed for a label, never the remote command.
function M.ssh_destination(args)
  local user, port, destination
  local takes_value = "BbcDEeFIiJLlmOoPpQRSWw"
  local index = 2
  while index <= #args do
    local arg = args[index]
    if arg == "--" then
      destination = args[index + 1]
      break
    elseif arg:sub(1, 1) ~= "-" then
      destination = arg
      break
    else
      local option = arg:sub(2, 2)
      if option ~= "" and takes_value:find(option, 1, true) then
        local value = arg:sub(3)
        if value == "" then
          index = index + 1
          value = args[index] or ""
        end
        if option == "l" then user = value end
        if option == "p" then port = value end
        if option == "o" then
          local key, setting = value:match "^([^= %s]+)[= %s]+(.+)$"
          if key and key:lower() == "user" then user = setting end
          if key and key:lower() == "port" then port = setting end
        end
      end
    end
    index = index + 1
  end
  if not destination then return end
  if user and not destination:find("@", 1, true) and not destination:find("://", 1, true) then
    destination = user .. "@" .. destination
  end
  if port and not destination:find("://", 1, true) then destination = destination .. ":" .. port end
  return clean(destination)
end

function M.inspect(term)
  local ok, pid = pcall(vim.fn.jobpid, term.job_id or -1)
  if not ok or pid <= 0 then pid = nil end
  local stat = pid and read(("/proc/%d/stat"):format(pid))
  local fields = stat and vim.split(stat:match "^%d+ %(.*%) (.*)$" or "", " ", { trimempty = true })
  local foreground = fields and tonumber(fields[6])
  local active = foreground and foreground > 0 and foreground or pid
  local args = active and vim.split(read(("/proc/%d/cmdline"):format(active)) or "", "\0", { trimempty = true }) or {}
  local name = active and read(("/proc/%d/comm"):format(active))
  name = name and vim.trim(name) or basename(vim.o.shell)
  local command = basename(args[1])
  if command == "ssh" then name = "ssh" end
  if command == "node" and (args[2] or ""):match "/codex[^/]*$" then name = "codex" end
  local cwd = active and uv.fs_readlink(("/proc/%d/cwd"):format(active))
    or pid and uv.fs_readlink(("/proc/%d/cwd"):format(pid))
    or term.dir
    or vim.fn.getcwd()
  local result = { process = clean(name), cwd = clean(cwd), name = term.display_name }
  if name == "ssh" then
    result.destination = M.ssh_destination(args)
    local title = term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr) and vim.b[term.bufnr].term_title or ""
    local host, path = title:match "^[^@%s]+@([^:%s]+):%s*(.+)$"
    -- Remote shells commonly report user@host: cwd via OSC 0/2. Ignore a stale local prompt.
    if host and host ~= uv.os_gethostname() and (path:sub(1, 1) == "/" or path:sub(1, 1) == "~") then
      result.remote_cwd = clean(path)
      result.remote_host = clean(host)
    end
  end
  return result
end

local function home_path(path)
  local home = uv.os_homedir()
  if home and path == home then return "~" end
  if home and path:sub(1, #home + 1) == home .. "/" then return "~" .. path:sub(#home + 1) end
  return path
end

function M.format(info, compact)
  local command = info.process
  if info.destination then
    local destination = info.destination
    local host = destination:gsub("^ssh://", ""):gsub("^.-@", ""):gsub(":%d+$", "")
    if info.remote_host and info.remote_host ~= host then
      if compact then
        destination = (destination:match "^(.-@)" or "") .. info.remote_host
      else
        destination = destination .. " [" .. info.remote_host .. "]"
      end
    end
    command = "ssh " .. destination
  end
  local cwd = home_path(info.cwd)
  if compact then
    cwd = info.remote_cwd or cwd
    if cwd ~= "~" and cwd ~= "/" then cwd = vim.fn.fnamemodify(cwd, ":t") end
    if info.destination and not info.remote_cwd then cwd = "лок: " .. cwd end
  elseif info.remote_cwd then
    cwd = info.remote_cwd .. " (из " .. cwd .. ")"
  elseif info.destination then
    cwd = "локально: " .. cwd
  end
  local label = command .. " · " .. cwd
  if info.name and info.name ~= "" then label = clean(info.name) .. " — " .. label end
  return label
end

return M
