local M = {}
local states = {}
local attached = {}
local aliases = { sh = "sh", bash = "sh", py = "python", js = "javascript", ts = "typescript" }

function M.setup()
  if M.ready then return end
  M.ready = true
  -- Колонка YAML-заголовка не равна колонке первой строки кода.
  vim.treesitter.query.add_directive("yaml-block-body!", function(match, _, _, predicate, metadata)
    local id = predicate[2]
    local node = match[id] and match[id][1]
    if not node then return end
    local row, _, last, col = node:range()
    metadata[id] = metadata[id] or {}
    metadata[id].range = { row + 1, 0, last, col }
  end, { all = true, force = true })
  vim.treesitter.query.add_directive("hcl-block-language!", function(match, _, source, predicate, metadata)
    local id = predicate[2]
    local node = match[id] and match[id][1]
    if not node then return end
    local identifiers = {}
    for child in node:iter_children() do
      if child:type() == "heredoc_identifier" then identifiers[#identifiers + 1] = child end
    end
    if #identifiers < 2 then return end
    local row, col = node:range()
    local last = identifiers[#identifiers]:range()
    if row + 1 >= last then return end
    local line = type(source) == "number" and vim.api.nvim_buf_get_lines(source, row, row + 1, false)[1]
      or vim.split(source, "\n", { plain = true })[row + 1]
    local language = line:sub(1, col):match "/%*[ \t]*([%a][%w_%-]*)[ \t]*%*/[ \t]*$"
      or vim.treesitter.get_node_text(identifiers[1], source)
    language = language:lower()
    local parsers = { sh = "bash", py = "python", js = "javascript", ts = "typescript" }
    metadata["injection.language"] = parsers[language] or language
    metadata[id] = metadata[id] or {}
    metadata[id].range = { row + 1, 0, last, 0 }
  end, { all = true, force = true })
end

local function marker(line, kind)
  if kind == "hcl" then
    local language = line:match "/%*[ \t]*([%a][%w_%-]*)[ \t]*%*/[ \t]*<<%-?[%w_%-]+[ \t]*$"
      or line:match "<<%-?([%a_][%w_%-]*)[ \t]*$"
    return language and language:lower()
  end
  return line:match "[|>][%d%+%-]*[ \t]+#[ \t]*([%a][%w_%-]*)[ \t]*$"
end

local function active(buf, kind)
  local syntax = vim.bo[buf].syntax
  return kind == "hcl" and (syntax:match "^hcl" or syntax:match "^terraform") or kind == "yaml" and syntax:match "^yaml"
end

local function include(language)
  local context = states[vim.api.nvim_get_current_buf()]
  if not context then return end
  local state = context.languages
  if state[language] ~= nil then return end
  state[language] = false
  local syntax = aliases[language] or language
  if #vim.api.nvim_get_runtime_file("syntax/" .. syntax .. ".vim", false) == 0 then return end
  local suffix = language:gsub("-", "_")
  local cluster = "EmbeddedBlock_" .. suffix
  local current = vim.b.current_syntax
  vim.b.current_syntax = nil
  if syntax == "sh" then vim.b.is_bash = 1 end
  vim.b.embedded_block_syntax = syntax
  vim.b.embedded_blocks_including = true
  local ok = pcall(vim.cmd, "syntax include @" .. cluster .. " syntax/embedded_block_include.vim")
  vim.b.embedded_blocks_including = nil
  vim.b.embedded_block_syntax = nil
  vim.b.current_syntax = current
  if not ok then return end
  -- Включённый syntax иногда задаёт своё правило синхронизации до его обёртки.
  vim.cmd "syntax sync clear"
  vim.cmd "syntax sync fromstart"
  if context.kind == "hcl" then
    local body = "HclEmbeddedBody_" .. suffix
    local language_pattern = [[\c]] .. language .. [[\C]]
    local annotation = [[/\*[ \t]*]] .. language_pattern .. [[[ \t]*\*/[ \t]*]]
    local any_annotation = [[/\*[ \t]*[A-Za-z][A-Za-z0-9_-]*[ \t]*\*/[ \t]*]]
    local starts = {
      [[\%(]] .. annotation .. [[\)\@<=<<-\?\z([A-Za-z_][A-Za-z0-9_-]*\)[ \t]*$]],
      [[\%(]] .. any_annotation .. [[\)\@<!<<-\?\z(]] .. language_pattern .. [[\)[ \t]*$]],
    }
    for _, start in ipairs(starts) do
      vim.cmd(
        "syntax region "
          .. body
          .. " matchgroup=hclBraces start=+"
          .. start
          .. [[+ end=+\C^[ \t]*\z1[ \t]*$+ keepend contains=@]]
          .. cluster
          .. ",jinjaTagBlock,jinjaVarBlock,jinjaComment,hclStringInterp"
      )
    end
    state[language] = true
    return
  end
  local body = "YamlBlockBody_" .. suffix
  local literal = vim.fn.escape(language, [[\.^$~[]*]])
  vim.cmd(
    "syntax match yamlBlockScalarHeader"
      .. [[ /[|>]\%([1-9][+-]\|[+-]\?[1-9]\?\)[ \t]\+#[ \t]*]]
      .. literal
      .. [[\s*$/ contained contains=yamlComment nextgroup=]]
      .. body
      .. " skipnl skipempty skipwhite"
  )
  vim.cmd(
    "syntax region "
      .. body
      .. [[ start=/^\z(\s\+\)\ze\S/ skip=/^\s*$/ end=/^\%(\z1\)\@!/ contained keepend contains=@]]
      .. cluster
      .. ",jinjaTagBlock,jinjaVarBlock,jinjaComment"
  )
  state[language] = true
end

function M.syntax(kind)
  kind = kind or "yaml"
  if vim.b.embedded_blocks_including or vim.b.yaml_blocks_including then return end
  M.setup()
  local buf = vim.api.nvim_get_current_buf()
  states[buf] = { kind = kind, languages = {} }
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local language = marker(line, kind)
    if language then include(language) end
  end
  if attached[buf] then return end
  attached[buf] = true
  vim.api.nvim_buf_attach(buf, false, {
    on_lines = function(_, _, _, first, _, last)
      local context = states[buf]
      if not context or not active(buf, context.kind) then return end
      local found = {}
      for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, first, last, false)) do
        local language = marker(line, context.kind)
        if language and states[buf] and states[buf].languages[language] == nil then found[language] = true end
      end
      if not next(found) then return end
      vim.schedule(function()
        if not vim.api.nvim_buf_is_loaded(buf) or not active(buf, context.kind) then return end
        vim.api.nvim_buf_call(buf, function()
          for language in pairs(found) do
            include(language)
          end
          vim.cmd.redraw()
        end)
      end)
    end,
    on_detach = function()
      states[buf] = nil
      attached[buf] = nil
    end,
  })
end

return M
