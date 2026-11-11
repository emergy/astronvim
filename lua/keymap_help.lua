local M = {}

function M.visible(mapping)
  return vim.fn.match(mapping.lhs or "", "[А-Яа-яЁё]") == -1 and not (mapping.desc or ""):find("LM (", 1, true)
end

-- Встроенная справка Snacks читает все карты буфера и не имеет фильтра.
-- Сохраняем её раскладку и закрытие, отбирая записи до формирования колонок.
function M.toggle(source)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "snacks_win_help" then
      vim.api.nvim_win_close(win, true)
      return
    end
  end
  local keys, done = {}, {}
  for _, mode in ipairs { "n", "i" } do
    for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(source.buf, mode)) do
      local key = Snacks.util.normkey(mapping.lhs)
      if M.visible(mapping) and not done[key] and not (mapping.desc or ""):find "which%-key" then
        done[key] = true
        keys[#keys + 1] = { key = key, desc = mapping.desc or "" }
      end
    end
  end
  table.sort(keys, function(a, b) return (a.desc .. a.key) < (b.desc .. b.key) end)
  local help = Snacks.win.new {
    style = "help",
    show = false,
    focusable = false,
    zindex = source.opts.zindex + 1,
    bo = { filetype = "snacks_win_help" },
  }
  source:on("WinClosed", function() help:close() end, { win = true })
  source:on("BufLeave", function() help:close() end, { buf = true })
  local width = 30
  local cols = math.max(1, math.floor((help:dim().width - 1) / width))
  local rows = math.max(1, math.ceil(#keys / cols))
  help.opts.height = rows
  help:show()
  local lines, chunks = {}, {}
  local function pad(text, size, right)
    if vim.api.nvim_strwidth(text) > size then text = vim.fn.strcharpart(text, 0, size - 1) .. "…" end
    local space = string.rep(" ", math.max(0, size - vim.api.nvim_strwidth(text)))
    return right and space .. text or text .. space
  end
  for row = 1, rows do
    lines[row], chunks[row] = "", {}
    for col = 1, cols do
      local item = keys[(col - 1) * rows + row]
      if item then
        vim.list_extend(chunks[row], {
          { pad(item.key, 10, true), "SnacksWinKey" },
          { " ➜ ", "SnacksWinKeySep" },
          { pad(item.desc, width - 13), "SnacksWinKeyDesc" },
        })
      end
    end
  end
  vim.api.nvim_buf_set_lines(help.buf, 0, -1, false, lines)
  local ns = vim.api.nvim_create_namespace "user.keymap_help"
  for row, text in ipairs(chunks) do
    vim.api.nvim_buf_set_extmark(help.buf, ns, row - 1, 0, { virt_text = text, virt_text_pos = "overlay" })
  end
end

return M
