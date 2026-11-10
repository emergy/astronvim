-- Самостоятельный терминал: без Lazy, AstroNvim и настроек редактора.
local M = { sessions = {} }
local api, uv = vim.api, vim.uv or vim.loop
local root = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))
local sequence, directory, draft, stopping = 0, nil, nil, false
local prefix = "<C-Space>"

local function current() return M.sessions[api.nvim_get_current_buf()] end

local function cwd(session)
  if session and session.job and not session.dead then
    local ok, pid = pcall(vim.fn.jobpid, session.job)
    local path = ok and pid > 0 and uv.fs_readlink("/proc/" .. pid .. "/cwd")
    if path and vim.fn.isdirectory(path) == 1 then session.cwd = path end
  end
  return session and session.cwd or vim.fn.getcwd()
end

local function private_write(path, text, append)
  local fd, err = uv.fs_open(path, append and "a" or "w", 384)
  assert(fd, err)
  local ok, write_error = uv.fs_write(fd, text, append and -1 or 0)
  uv.fs_close(fd)
  assert(ok, write_error)
end

local function record(session, command)
  local state = vim.fn.stdpath "state" .. "/nterm"
  vim.fn.mkdir(state, "p", 448)
  private_write(state .. "/commands.jsonl", vim.json.encode {
    time = os.date "!%Y-%m-%dT%H:%M:%SZ",
    cwd = cwd(session),
    command = command,
  } .. "\n", true)
end

local function clean(session)
  for _, path in ipairs { session.command_file, session.edit_file } do
    uv.fs_unlink(path)
  end
end

local function enter(session)
  session = session or current()
  if not session or session.dead then return end
  for _, win in ipairs(vim.fn.win_findbuf(session.buf)) do
    if api.nvim_win_get_tabpage(win) == api.nvim_get_current_tabpage() then
      api.nvim_set_current_win(win)
      vim.cmd.startinsert()
      return
    end
  end
end

function M.close(session)
  session = session or current()
  if not session or session.closing then return end
  local normal = vim.tbl_filter(
    function(win) return api.nvim_win_get_config(win).relative == "" end,
    api.nvim_list_wins()
  )
  if #normal == 1 and api.nvim_win_get_buf(normal[1]) == session.buf then
    vim.cmd "confirm quit"
    return
  end
  session.closing = true
  if session.job and not session.dead then vim.fn.jobstop(session.job) end
  for _, win in ipairs(vim.fn.win_findbuf(session.buf)) do
    api.nvim_win_close(win, true)
  end
  M.sessions[session.buf] = nil
  if api.nvim_buf_is_valid(session.buf) then api.nvim_buf_delete(session.buf, { force = true }) end
  clean(session)
  if current() then enter() end
end

local function command_text()
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    local lines = vim.fn.getregion(vim.fn.getpos "v", vim.fn.getpos ".", {
      type = mode,
      exclusive = vim.o.selection == "exclusive",
    })
    vim.cmd.normal { args = { api.nvim_replace_termcodes("<Esc>", true, false, true) }, bang = true }
    return table.concat(lines, "\n")
  end
  return api.nvim_get_current_line()
end

function M.run_command()
  if not draft or not api.nvim_buf_is_valid(draft.buf) then return end
  local session = draft.session
  if session.dead or not session.ready then
    vim.notify("Bash занят: вернитесь к его приглашению", vim.log.levels.WARN)
    return
  end
  local command = table.concat(api.nvim_buf_get_lines(draft.buf, 0, -1, false), "\n")
  if not command:find "%S" or command:find("\0", 1, true) then
    vim.notify("Нужна непустая команда без NUL", vim.log.levels.WARN)
    return
  end
  local ok, err = pcall(function()
    private_write(session.command_file, command)
    record(session, command)
  end)
  if not ok then
    vim.notify(tostring(err), vim.log.levels.ERROR)
    return
  end
  local sent, send_error = pcall(api.nvim_chan_send, session.job, "\24\29")
  if not sent then
    vim.notify(tostring(send_error), vim.log.levels.ERROR)
    return
  end
  session.ready = false
  local win = draft.win
  vim.bo[draft.buf].modified = false
  draft = nil
  api.nvim_win_close(win, true)
  enter(session)
end

function M.edit_command(text, session)
  session = session or current()
  if not session or session.dead then return end
  if draft and api.nvim_win_is_valid(draft.win) then
    api.nvim_set_current_win(draft.win)
    return
  end
  text = text or command_text()
  vim.cmd.stopinsert()
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].buftype, vim.bo[buf].bufhidden = "acwrite", "wipe"
  vim.bo[buf].swapfile, vim.bo[buf].undofile = false, false
  vim.bo[buf].filetype = "sh"
  api.nvim_buf_set_name(buf, "nterm-command://" .. session.id)
  api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
  vim.bo[buf].modified = true
  local width, height = math.max(12, vim.o.columns - 4), math.max(3, vim.o.lines - 6)
  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    row = 1,
    col = 1,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Команда · :wq / :q! ",
  })
  vim.wo[win].wrap, vim.wo[win].linebreak = true, true
  draft = { buf = buf, win = win, session = session }
  api.nvim_create_autocmd("BufWriteCmd", { buffer = buf, callback = function() vim.bo[buf].modified = false end })
  api.nvim_buf_create_user_command(buf, "NtermRun", M.run_command, { bang = true })
  -- Явное выполнение: :wq; обычное закрытие окна всегда отменяет запуск.
  vim.cmd [[cnoreabbrev <buffer> <expr> wq getcmdtype()==':' && getcmdline() =~# '^\s*wq$' ? 'NtermRun' : 'wq']]
  vim.cmd [[cnoreabbrev <buffer> <expr> x getcmdtype()==':' && getcmdline() =~# '^\s*x$' ? 'NtermRun' : 'x']]
  api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      if draft and draft.win == win then
        draft = nil
        vim.schedule(function() enter(session) end)
      end
    end,
  })
end

local function attach(session)
  local function map(mode, key, value) vim.keymap.set(mode, key, value, { buffer = session.buf, silent = true }) end
  map("t", prefix, [[<C-\><C-n>]])
  map("n", prefix, function()
    api.nvim_chan_send(session.job, "\0")
    enter(session)
  end)
  -- Стандартный escape вложенного Vim должен доходить до него.
  vim.keymap.set(
    "t",
    [[<C-\>]],
    function() api.nvim_chan_send(session.job, "\28") end,
    { buffer = session.buf, nowait = true, silent = true }
  )
  for _, key in ipairs { "i", "a", "I", "A" } do
    map("n", key, function() enter(session) end)
  end
  map({ "n", "x" }, "<Space>e", function() M.edit_command() end)
  map("n", "<Space>j", function()
    local path = vim.fn.stdpath "data" .. "/lazy/hop.nvim"
    if vim.fn.isdirectory(path) == 0 then
      vim.notify("Hop не установлен", vim.log.levels.WARN)
      return
    end
    if not package.loaded.hop then
      vim.opt.rtp:append(path)
      require("hop").setup {}
    end
    require("hop").hint_lines { multi_windows = false }
  end)
end

function M.open(kind)
  local dir = cwd(current())
  if kind == "tab" then
    vim.cmd.tabnew()
  elseif kind == "horizontal" then
    vim.cmd "belowright split"
  elseif kind == "vertical" then
    vim.cmd "belowright vsplit"
  end
  local buf = api.nvim_create_buf(false, true)
  api.nvim_set_current_buf(buf)
  sequence = sequence + 1
  local session = { id = sequence, buf = buf, cwd = dir }
  session.token = vim.fn.sha256(tostring(uv.hrtime()) .. sequence):sub(1, 24)
  session.command_file, session.edit_file =
    directory .. "/" .. sequence .. ".command", directory .. "/" .. sequence .. ".edit"
  M.sessions[buf] = session
  local bash = vim.fn.exepath "bash"
  assert(bash ~= "", "Для профиля нужен Bash")
  session.job = vim.fn.termopen({ bash, "--rcfile", root .. "/terminal/bashrc", "-i" }, {
    cwd = dir,
    env = {
      NTERM_TOKEN = session.token,
      NTERM_COMMAND_FILE = session.command_file,
      NTERM_EDIT_FILE = session.edit_file,
    },
    on_exit = function(_, code)
      session.dead, session.ready = true, false
      vim.schedule(function()
        if stopping or session.closing then return end
        if draft and draft.session == session then
          vim.notify("Bash завершён: " .. code)
          return
        end
        M.close(session)
      end)
    end,
  })
  assert(session.job > 0, "Не удалось запустить Bash")
  attach(session)
  vim.bo[buf].bufhidden = "hide"
  vim.cmd.startinsert()
  return session
end

function M.tabline()
  local result, active = {}, api.nvim_get_current_tabpage()
  for index, tab in ipairs(api.nvim_list_tabpages()) do
    local session = M.sessions[api.nvim_win_get_buf(api.nvim_tabpage_get_win(tab))]
    local label = session and vim.fn.fnamemodify(session.cwd, ":~:t") or "терминал"
    result[#result + 1] = ("%%#%s#%%%dT %d: %s %%T"):format(
      tab == active and "TabLineSel" or "TabLine",
      index,
      index,
      label:gsub("%%", "%%%%")
    )
  end
  return table.concat(result) .. "%#TabLineFill#%="
end

function M.statusline()
  local session = current()
  local mode = api.nvim_get_mode().mode:match "^t" and "ВВОД" or "NORMAL"
  return (" NTERM %s %%<%s %%= ^Space "):format(mode, (session and session.cwd or "команда"):gsub("%%", "%%%%"))
end

function M.help()
  local lines = {
    "NTERM — внешний слой терминала",
    "",
    "Ctrl+Space: внешний Normal; два раза: передать Ctrl+Space внутрь",
    "i: ввод · /, n/N: поиск · v/V/Ctrl-v, y: выделить/скопировать",
    "Space j: Hop · Space e: редактировать строку/выделение",
    "Ctrl-x Ctrl-e в Bash: редактировать текущую команду",
    ":wq в редакторе команды: выполнить · :q!: отменить",
    "",
    "Space tn: вкладка · Space th/tv: split · Space tc: закрыть панель",
    "Space t[/t]: предыдущая/следующая вкладка · Space 1…9/0: вкладка",
    "Ctrl-w h/j/k/l: окна · Space tq: выход",
    "",
    "Ввод редактируемой команды разрешён только в локальном Bash prompt.",
    "История команд: " .. vim.fn.stdpath "state" .. "/nterm/commands.jsonl",
  }
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    row = 1,
    col = 1,
    width = math.max(12, vim.o.columns - 4),
    height = math.min(#lines, math.max(3, vim.o.lines - 5)),
    style = "minimal",
    border = "rounded",
  })
  vim.wo[win].wrap, vim.wo[win].linebreak = true, true
  vim.bo[buf].bufhidden = "wipe"
  for _, key in ipairs { "q", "<Esc>" } do
    vim.keymap.set("n", key, function() api.nvim_win_close(win, true) end, { buffer = buf })
  end
end

function M.setup()
  if M.started then return end
  if vim.fn.argc(-1) > 0 then
    api.nvim_err_writeln "nterm не открывает файлы. Для редактора используйте nvim."
    vim.cmd "cquit 2"
    return
  end
  M.started = true
  vim.o.loadplugins, vim.o.modeline = false, false
  vim.o.shada = ""
  vim.o.swapfile, vim.o.backup, vim.o.writebackup, vim.o.undofile = false, false, false, false
  vim.o.scrollback, vim.o.showtabline, vim.o.laststatus = 100000, 2, 2
  vim.o.number, vim.o.relativenumber, vim.o.wrap, vim.o.hidden = false, false, false, true
  vim.o.mouse, vim.o.termguicolors = "a", true
  require("user_platform").setup_path()
  directory = assert(uv.fs_mkdtemp((vim.env.TMPDIR or "/tmp") .. "/nterm-XXXXXX"))
  vim.g.clipboard = {
    name = "nterm OSC52",
    copy = {
      ["+"] = require("vim.ui.clipboard.osc52").copy "+",
      ["*"] = require("vim.ui.clipboard.osc52").copy "*",
    },
    paste = {
      ["+"] = function() return { vim.fn.getreg("0", 1, true), vim.fn.getregtype "0" } end,
      ["*"] = function() return { vim.fn.getreg("0", 1, true), vim.fn.getregtype "0" } end,
    },
  }
  vim.o.tabline, vim.o.statusline =
    "%!v:lua.require'terminal_profile'.tabline()", "%!v:lua.require'terminal_profile'.statusline()"
  local group = api.nvim_create_augroup("NtermProfile", { clear = true })
  api.nvim_create_autocmd("TextYankPost", {
    group = group,
    callback = function()
      local event = vim.v.event
      if event.operator == "y" and event.regname ~= "+" and event.regname ~= "*" then
        vim.fn.setreg("+", event.regcontents, event.regtype)
      end
    end,
  })
  api.nvim_create_autocmd("TermRequest", {
    group = group,
    callback = function(args)
      local session = M.sessions[args.buf]
      if not session then return end
      local value = args.data.sequence:gsub("\7$", ""):gsub("\27\\$", "")
      if value == "\27]777;nterm;ready;" .. session.token then
        session.ready = true
        cwd(session)
        vim.cmd.redrawtabline()
      elseif value == "\27]777;nterm;busy;" .. session.token then
        session.ready = false
      elseif value == "\27]777;nterm;edit;" .. session.token then
        vim.schedule(function()
          local file = io.open(session.edit_file, "rb")
          if not file then return end
          local text = file:read "*a"
          file:close()
          uv.fs_unlink(session.edit_file)
          M.edit_command(text, session)
        end)
      end
    end,
  })
  api.nvim_create_autocmd("BufHidden", {
    group = group,
    callback = function(args)
      local session = M.sessions[args.buf]
      if session then
        vim.schedule(function()
          if not stopping and not session.closing and #vim.fn.win_findbuf(session.buf) == 0 then M.close(session) end
        end)
      end
    end,
  })
  api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    once = true,
    callback = function()
      stopping = true
      for _, session in pairs(M.sessions) do
        session.closing = true
        if session.job and not session.dead then pcall(vim.fn.jobstop, session.job) end
        clean(session)
      end
      uv.fs_rmdir(directory)
    end,
  })
  local function map(key, action) vim.keymap.set("n", "<Space>" .. key, action, { silent = true }) end
  map("tn", function() M.open "tab" end)
  map("th", function() M.open "horizontal" end)
  map("tv", function() M.open "vertical" end)
  map("tc", function() M.close() end)
  map("tq", function() vim.cmd "confirm qall" end)
  map("t[", function()
    vim.cmd.tabprevious()
    enter()
  end)
  map("t]", function()
    vim.cmd.tabnext()
    enter()
  end)
  map("?", M.help)
  for digit = 0, 9 do
    local index = digit == 0 and 10 or digit
    map(tostring(digit), function()
      local tab = api.nvim_list_tabpages()[index]
      if tab then
        api.nvim_set_current_tabpage(tab)
        enter()
      end
    end)
  end
  vim.schedule(function()
    if not stopping then M.open() end
  end)
end

M.current = current
return M
