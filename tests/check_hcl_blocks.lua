-- nvim --headless -u NONE -i NONE -l tests/check_hcl_blocks.lua
local root = vim.fn.getcwd()
vim.opt.rtp:prepend(root)
vim.opt.rtp:append(root .. "/after")
for _, name in ipairs { "nvim-treesitter", "ansible-vim" } do
  vim.opt.rtp:append(vim.fn.stdpath "data" .. "/lazy/" .. name)
end
require("embedded_blocks").setup()
vim.cmd "filetype plugin indent on"
vim.cmd "syntax enable"
local function groups(row)
  local result = {}
  for col = 1, #(vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or "") do
    result[vim.fn.synIDattr(vim.fn.synID(row, col, 1), "name")] = true
  end
  return result
end
local lines = {
  "default = /* yaml */ <<-EOT",
  "- vlan: 358",
  "  dhcp4-overrides:",
  "    send-hostname: false",
  "  nameservers:",
  "    - 192.0.2.2",
  "EOT",
  "shell = /* sh */ <<COMMAND",
  'echo "$HOME"',
  "COMMAND",
  "python = /* py */ <<-CODE",
  "def example():",
  "  return 42",
  "  CODE",
  "named = <<-YAML",
  "name: example",
  "YAML",
  "override = /* json */ <<-YAML",
  '{"key": true}',
  "YAML",
  "unknown = /* nonexistent_hcl_language */ <<-EOT",
  "plain text",
  "EOT",
  'quoted = "/* yaml */ <<-YAML"',
  "# /* yaml */ <<-YAML",
  "after = true",
}
for _, ft in ipairs { "hcl", "hcl.jinja2", "terraform" } do
  vim.cmd.enew { bang = true }
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = ft
  vim.bo.syntax = ft
  assert(groups(2).yamlBlockMappingKey and groups(2).yamlInteger, ft .. ": YAML missing")
  assert(groups(4).yamlBool, ft .. ": YAML boolean missing")
  assert(groups(9).shDerefSimple, ft .. ": shell missing")
  assert(groups(12).pythonFunction, ft .. ": Python missing")
  assert(groups(16).yamlBlockMappingKey, ft .. ": named YAML missing")
  assert(groups(19).jsonKeywordMatch, ft .. ": annotation did not override marker")
  assert(groups(22).hclHereDocText, ft .. ": unsupported language changed fallback")
  assert(groups(26).hclAttributeName and groups(26).hclValueBool, ft .. ": heredoc did not end")
  if ft == "hcl.jinja2" then
    vim.api.nvim_buf_set_lines(0, 1, 2, false, { '- name: "{{ user | lower }}"' })
    vim.cmd.redraw()
    assert(groups(2).jinjaVariable and groups(2).jinjaFilter, "Jinja missing inside YAML heredoc")
  end
end

-- Нативный парсер HCL либо установленный диалект Terraform той же грамматики.
vim.cmd.enew { bang = true }
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
local ok, parser = pcall(vim.treesitter.get_parser, 0, "hcl")
if not ok then parser = vim.treesitter.get_parser(0, "terraform") end
parser:parse(true)
local expected = { yaml = { 1, 15 }, bash = { 8 }, python = { 11 }, json = { 18 } }
local found = {}
for lang, child in pairs(parser:children()) do
  if expected[lang] then
    for _, tree in ipairs(child:trees()) do
      local first, _, last = tree:root():range()
      for row = first, last do
        found[row] = found[row] or {}
        found[row][lang] = true
      end
    end
  end
end
for lang, rows in pairs(expected) do
  for _, row in ipairs(rows) do
    assert(found[row] and found[row][lang], "native injection missing: " .. lang)
  end
end
assert(not found[18].yaml, "native named marker overrode explicit annotation")
assert(not found[25], "native injection escaped heredoc")

-- Новая метка после открытия и изменение языка без перечитывания файла.
vim.cmd.enew { bang = true }
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "after = true" })
vim.bo.filetype = "hcl.jinja2"
vim.bo.syntax = "hcl.jinja2"
vim.api.nvim_buf_set_lines(
  0,
  0,
  -1,
  false,
  { "value = /* py */ <<-EOT", "def dynamic():", "  return 1", "EOT", "after = true" }
)
assert(vim.wait(1000, function() return groups(2).pythonFunction end, 10), "new marker not activated")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "value = /* yaml */ <<-EOT", "name: example", "EOT", "after = true" })
assert(vim.wait(1000, function() return groups(2).yamlBlockMappingKey end, 10), "changed marker not activated")
vim.api.nvim_buf_set_lines(0, 0, 1, false, { "value = <<-EOT" })
vim.cmd.redraw()
assert(groups(2).hclHereDocText and not groups(2).yamlBlockMappingKey, "removed marker still active")
assert(groups(4).hclAttributeName, "live edit escaped heredoc")
print "PASS: HCL heredoc annotations, << and <<-, named markers, precedence, YAML/shell/Python/JSON, Jinja, native parsers, boundaries and live edits"
