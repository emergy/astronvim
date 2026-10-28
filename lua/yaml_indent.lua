local M = {}
local expression = "v:lua.require'yaml_indent'.indent()"

-- Заголовок YAML-скаляра вне кавычек и комментариев: |-, >+, |2- и т. п.
local function header(line)
  local quote, index = nil, 1
  while index <= #line do
    local char = line:sub(index, index)
    if quote then
      if char == quote then
        if quote == "'" and line:sub(index + 1, index + 1) == "'" then
          index = index + 1
        else
          quote = nil
        end
      elseif quote == '"' and char == "\\" then
        index = index + 1
      end
    elseif char == "#" and (index == 1 or line:sub(index - 1, index - 1):match("%s")) then
      return
    elseif (char == "'" or char == '"')
      and (index == 1 or line:sub(index - 1, index - 1):match("[%s:%-?%[%]{},]"))
    then
      quote = char
    elseif char == "|" or char == ">" then
      local prefix, suffix = line:sub(1, index - 1), line:sub(index + 1)
      local properties = prefix:match("^.*:%s+(.*)$") or prefix:match("^%s*%-%s+(.*)$")
      local valid = properties ~= nil
      for property in (properties or ""):gmatch("%S+") do
        if not property:match("^[!&]") then valid = false end
      end
      if valid
        and (suffix:match("^[+-]?[1-9]?%s*$") or suffix:match("^[1-9][+-]?%s*$")
          or suffix:match("^[+-]?[1-9]?%s+#") or suffix:match("^[1-9][+-]?%s+#"))
      then
        return tonumber(suffix:match("[1-9]")) or 0
      end
    end
    index = index + 1
  end
end

function M.indent(lnum)
  lnum = lnum or vim.v.lnum
  local block
  for row, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, lnum - 1, false)) do
    if line:find("%S") then
      local indent = vim.fn.indent(row)
      if block and indent > block.parent and (not block.content or indent >= block.content) then
        block.content = block.content or indent
        block.has_content = true
      else
        block = nil
        local indicator = header(line)
        if indicator then
          block = { parent = indent, content = indicator > 0 and indent + indicator or nil }
        end
      end
    end
  end

  if block then
    local line = vim.fn.getline(lnum)
    local indent = vim.fn.indent(lnum)
    if not line:find("%S") or indent >= (block.content or block.parent + 1) then
      -- Первую строку сдвигаем внутрь скаляра; остальные оставляем как ввёл пользователь.
      if not block.has_content and not line:find("%S") then
        return block.content or block.parent + vim.fn.shiftwidth()
      end
      return -1
    end
  end
  local original = vim.b.yaml_indent_original:gsub("v:lnum", tostring(lnum))
  return vim.fn.eval(original)
end

function M.setup()
  local original = vim.bo.indentexpr
  if original == expression then return end
  if original ~= "GetYAMLIndent(v:lnum)" and original ~= "GetAnsibleIndent(v:lnum)" then return end
  vim.b.yaml_indent_original = original
  vim.bo.indentexpr = expression
end

return M
