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
end

local function marker(line) return line:match "[|>][%d%+%-]*[ \t]+#[ \t]*([%a][%w_%-]*)[ \t]*$" end

local function include(language)
  local state = states[vim.api.nvim_get_current_buf()]
  if not state or state[language] ~= nil then return end
  state[language] = false
  local syntax = aliases[language] or language
  if #vim.api.nvim_get_runtime_file("syntax/" .. syntax .. ".vim", false) == 0 then return end
  local suffix = language:gsub("-", "_")
  local cluster = "YamlBlock_" .. suffix
  local current = vim.b.current_syntax
  vim.b.current_syntax = nil
  if syntax == "sh" then vim.b.is_bash = 1 end
  vim.b.yaml_block_syntax = syntax
  vim.b.yaml_blocks_including = true
  local ok = pcall(vim.cmd, "syntax include @" .. cluster .. " syntax/yaml_block_include.vim")
  vim.b.yaml_blocks_including = nil
  vim.b.yaml_block_syntax = nil
  vim.b.current_syntax = current
  if not ok then return end
  -- Включённый syntax иногда задаёт своё правило синхронизации до его обёртки.
  vim.cmd "syntax sync clear"
  vim.cmd "syntax sync fromstart"
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

function M.syntax()
  if vim.b.yaml_blocks_including then return end
  M.setup()
  local buf = vim.api.nvim_get_current_buf()
  states[buf] = {}
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local language = marker(line)
    if language then include(language) end
  end
  if attached[buf] then return end
  attached[buf] = true
  vim.api.nvim_buf_attach(buf, false, {
    on_lines = function(_, _, _, first, _, last)
      if not vim.bo[buf].syntax:match "^yaml" then return end
      local found = {}
      for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, first, last, false)) do
        local language = marker(line)
        if language and states[buf] and states[buf][language] == nil then found[language] = true end
      end
      if not next(found) then return end
      vim.schedule(function()
        if not vim.api.nvim_buf_is_loaded(buf) or not vim.bo[buf].syntax:match "^yaml" then return end
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
