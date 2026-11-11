-- nvim --headless -u NONE -i NONE -l tests/check_yaml_blocks.lua
local root = vim.fn.getcwd()
vim.opt.rtp:prepend(root)
vim.opt.rtp:append(root .. "/after")
for _, name in ipairs { "nvim-treesitter", "ansible-vim" } do
  vim.opt.rtp:append(vim.fn.stdpath "data" .. "/lazy/" .. name)
end
require("yaml_blocks").setup()
vim.cmd "filetype plugin indent on"
vim.cmd "syntax enable"
local lines, blocks = { "steps:" }, {}
local function block(header, indent, lang)
  lines[#lines + 1] = header
  local row = #lines
  local code = lang == "python" and { "def example():", "  return 42" } or { 'echo "$HOME"', "printf '%s\\n' ok" }
  for _, line in ipairs(code) do
    lines[#lines + 1] = string.rep(" ", indent) .. line
  end
  blocks[#blocks + 1] = { row = row, lang = lang }
end
for _, style in ipairs { "|", "|-", ">", ">-" } do
  block("  - " .. style .. " # sh", 4, "bash")
  block("  - " .. style .. " # py", 4, "python")
end
block("very_long_mapping_key: |- # python", 2, "python")
block("script: |- # py", 2, "python")
block("before_script: |- # bash", 2, "bash")
block("tagged: !!str | # py", 2, "python")
block("after_script: |-", 2, "bash") -- Штатная инъекция без явной метки.
lines[#lines + 1] = "unknown: | # nonexistent_yaml_block_language"
lines[#lines + 1] = "  just text"
lines[#lines + 1] = "empty: | # py"
lines[#lines + 1] = 'quoted: "| # py"'
lines[#lines + 1] = "# not a block: | # py"
lines[#lines + 1] = "tail: 7"

local function groups(row)
  local result = {}
  for col = 1, #(vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or "") do
    result[vim.fn.synIDattr(vim.fn.synID(row, col, 1), "name")] = true
  end
  return result
end
for _, ft in ipairs { "yaml", "yaml.ansible", "yaml.jinja2" } do
  vim.cmd.enew { bang = true }
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = ft
  vim.bo.syntax = ft
  for index, item in ipairs(blocks) do
    -- Последний блок без метки в regex-режиме сохраняет штатную YAML-подсветку.
    if index < #blocks then
      local g = groups(item.row + 1)
      assert(
        item.lang == "bash" and g.shDerefSimple or item.lang == "python" and g.pythonFunction,
        ft .. ": embedded " .. item.lang
      )
    end
  end
  assert(groups(#lines).yamlBlockMappingKey, ft .. ": highlighting escaped the block")
  if ft == "yaml.jinja2" then
    vim.api.nvim_buf_set_lines(0, blocks[1].row, blocks[1].row + 1, false, { '    echo "{{ user | lower }}"' })
    assert(groups(blocks[1].row + 1).jinjaVariable, "Jinja lost inside shell")
  end
end

-- Настоящие дочерние парсеры: явный Python подавляет автоматический Bash для script.
vim.cmd.enew { bang = true }
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.bo.filetype = "yaml"
local parser = vim.treesitter.get_parser(0, "yaml")
parser:parse(true)
vim.treesitter.start(0, "yaml")
local captures = vim.treesitter.get_captures_at_pos(0, blocks[2].row, 4)
assert(vim.iter(captures):any(function(capture) return capture.lang == "python" end), "native Python captures missing")
local languages = {}
for lang, child in pairs(parser:children()) do
  if lang == "bash" or lang == "python" then
    for _, tree in ipairs(child:trees()) do
      local first, _, last = tree:root():range()
      for row = first + 1, last + 1 do
        languages[row] = languages[row] or {}
        languages[row][lang] = true
      end
    end
  end
end
for _, item in ipairs(blocks) do
  local found = languages[item.row + 1] or {}
  assert(found[item.lang], "missing Tree-sitter " .. item.lang .. " at " .. (item.row + 1))
  assert(not found[item.lang == "bash" and "python" or "bash"], "overlapping injection languages")
end

-- Язык, добавленный после открытия буфера, включается без перечитывания файла.
vim.cmd.enew { bang = true }
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "value: 1" })
vim.bo.filetype = "yaml.jinja2"
vim.bo.syntax = "yaml.jinja2"
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "code: |- # py", "  def dynamic():", "    return 1", "next: 2" })
assert(vim.wait(1000, function() return groups(2).pythonFunction end, 10), "new marker not activated")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "code: >- # sh", '  echo "$HOME"', "next: 2" })
assert(vim.wait(1000, function() return groups(2).shDerefSimple end, 10), "changed marker not activated")
assert(groups(3).yamlBlockMappingKey, "changed marker leaked into next node")
vim.api.nvim_buf_set_lines(0, 0, 1, false, { "code: |-" })
vim.cmd.redraw()
assert(not groups(2).shDerefSimple, "removed marker still active")

-- Heredoc не должен поглощать следующий YAML-узел или соседний язык.
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "commands:",
  "  - | # sh",
  "    cat <<'EOF'",
  "    literal $HOME",
  "    EOF",
  "  - >- # py",
  "    print(1)",
  "tail: 7",
})
vim.cmd.redraw()
assert(groups(4).shHereDoc, "shell heredoc not highlighted")
assert(groups(7).pythonBuiltin, "heredoc swallowed next language")
assert(groups(8).yamlBlockMappingKey, "heredoc swallowed YAML")

-- Начальные пустые строки допускаются, длинный блок не теряет контекст языка.
local long = { "code: |- # py", "", "  ", "  def long_block():" }
for _ = 1, 250 do
  long[#long + 1] = "    # body"
end
long[#long + 1] = "    return 42"
long[#long + 1] = "tail: 7"
vim.api.nvim_buf_set_lines(0, 0, -1, false, long)
vim.cmd.redraw()
assert(groups(4).pythonFunction and groups(#long - 1).pythonStatement, "long/blank block lost its syntax")
assert(groups(#long).yamlBlockMappingKey, "long block swallowed YAML")
print "PASS: all four YAML scalar styles, mapping/sequence blocks, aliases, mixed languages, Jinja, native injections, defaults, boundaries and live edits"
