local M = {}
local alphabet = "asdfghjklqwertyuiopzxcvbnm"

local function label(index, length)
  local result = ""
  index = index - 1
  for _ = 1, length do
    local digit = index % #alphabet + 1
    result = alphabet:sub(digit, digit) .. result
    index = math.floor(index / #alphabet)
  end
  return result
end

local function fit(text, width)
  if vim.fn.strdisplaywidth(text) <= width then return text end
  while vim.fn.strdisplaywidth(text) > width - 1 do
    text = vim.fn.strcharpart(text, 0, vim.fn.strchars(text) - 1)
  end
  return text .. "…"
end

function M.open()
  local origin = vim.api.nvim_get_current_win()
  local current = vim.api.nvim_get_current_buf()
  local buffers, seen = {}, {}
  local function add(buf)
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted and not seen[buf] then
      buffers[#buffers + 1] = buf
      seen[buf] = true
    end
  end
  for _, buf in ipairs(vim.t.bufs or {}) do add(buf) end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do add(buf) end
  if #buffers == 0 then return end

  local width = math.max(1, math.min(160, vim.o.columns - 4))
  local columns = math.max(1, math.floor(width / 38))
  local cell_width = math.floor(width / columns)
  local max_rows = math.max(1, vim.o.lines - 8)
  local page_size = columns * max_rows
  local pages = math.ceil(#buffers / page_size)
  local page, prefix = 1, ""
  local length = 1
  while (#alphabet) ^ length < math.min(#buffers, page_size) do length = length + 1 end
  local height = math.min(max_rows, math.ceil(#buffers / columns))
  local menu = vim.api.nvim_create_buf(false, true)
  vim.bo[menu].bufhidden = "wipe"
  local win = vim.api.nvim_open_win(menu, false, {
    relative = "editor",
    row = math.max(0, math.floor((vim.o.lines - height - 2) / 2)),
    col = math.max(0, math.floor((vim.o.columns - width - 2) / 2)),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    focusable = false,
    zindex = 100,
    footer = " Буквы — выбор · Esc — отмена · Tab / Shift-Tab — страницы ",
    footer_pos = "center",
  })
  local ns = vim.api.nvim_create_namespace "user_buffer_menu"
  local function draw()
    local lines, marks = {}, {}
    local first = (page - 1) * page_size + 1
    local last = math.min(#buffers, page * page_size)
    for index = first, last do
      local local_index = index - first + 1
      local row = math.floor((local_index - 1) / columns) + 1
      local buf = buffers[index]
      local key = label(local_index, length)
      local name = vim.api.nvim_buf_get_name(buf)
      name = name == "" and "[Без имени]"
        or vim.fn.fnamemodify(name, ":t") .. "  " .. vim.fn.fnamemodify(name, ":~:.:h")
      name = name:gsub("[%c]", " ")
      local text = (buf == current and "* " or "  ") .. key .. "  "
      text = fit(text .. (vim.bo[buf].modified and "[+] " or "") .. name, cell_width - 2)
      local start = #(lines[row] or "")
      lines[row] = (lines[row] or "") .. text .. string.rep(" ", cell_width - vim.fn.strdisplaywidth(text))
      marks[#marks + 1] = { row - 1, start, start + #text, key:sub(1, #prefix) == prefix }
    end
    vim.bo[menu].modifiable = true
    vim.api.nvim_buf_set_lines(menu, 0, -1, false, lines)
    vim.bo[menu].modifiable = false
    vim.api.nvim_buf_clear_namespace(menu, ns, 0, -1)
    for _, mark in ipairs(marks) do
      vim.api.nvim_buf_add_highlight(menu, ns, mark[4] and "NormalFloat" or "Comment", mark[1], mark[2], mark[3])
      if mark[4] then
        vim.api.nvim_buf_add_highlight(menu, ns, "Special", mark[1], mark[2] + 2, mark[2] + 2 + length)
      end
    end
    vim.api.nvim_win_set_config(win, {
      title = (" Буферы: %d · %d/%d%s "):format(#buffers, page, pages, prefix ~= "" and " · " .. prefix or ""),
      title_pos = "center",
    })
    vim.cmd.redraw()
  end

  local selected
  local ok, err = pcall(function()
    while true do
      draw()
      local key = vim.fn.getcharstr()
      local translated = vim.fn.keytrans(key)
      if key == "\027" or key == "\003" then break end
      if key == "\t" or translated == "<PageDown>" then
        page, prefix = page % pages + 1, ""
      elseif translated == "<S-Tab>" or translated == "<PageUp>" then
        page, prefix = (page - 2) % pages + 1, ""
      elseif translated == "<BS>" or key == "\127" then
        prefix = prefix:sub(1, -2)
      elseif #key == 1 and alphabet:find(key, 1, true) then
        prefix = prefix .. key
        if #prefix == length then
          for index = 1, math.min(page_size, #buffers - (page - 1) * page_size) do
            if label(index, length) == prefix then
              selected = buffers[(page - 1) * page_size + index]
              return
            end
          end
          prefix = ""
        end
      end
    end
  end)
  if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  if not ok then
    if not tostring(err):match("Interrupt") then vim.notify(tostring(err), vim.log.levels.ERROR) end
    return
  end
  if selected and vim.api.nvim_buf_is_valid(selected) and vim.api.nvim_win_is_valid(origin) then
    local switched, reason = pcall(vim.api.nvim_win_set_buf, origin, selected)
    if not switched then vim.notify(tostring(reason), vim.log.levels.WARN) end
  end
end

return M
