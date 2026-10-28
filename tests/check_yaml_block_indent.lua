vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:append(vim.fn.getcwd() .. '/after')
vim.opt.rtp:prepend(vim.fn.expand('~/.local/share/nvim/lazy/ansible-vim'))
vim.o.expandtab = true
vim.o.autoindent = true
vim.cmd 'filetype indent on'
local function keys(s)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(s, true, false, true), 'nx', false)
end
local sample = {
  'antimatket_keys: |-',
  "  #jinja2: line_statement_prefix: '>', trim_blocks: True, lstrip_blocks: True",
  "  > set scan_root = './'",
  '  > set template_files = (',
  "      q('community.general.filetree', scan_root)",
  "      | selectattr('state', 'eq', 'file')",
  "      | map(attribute='path')",
  '      | list',
  '    )',
  '  > set result = namespace(value={})',
  '  > for file in template_files',
  "  >   set dict_path_keys = file.split('/')",
  "  >   if dict_path_keys[0] is search('-keys$')",
  '  >     set branch = namespace(',
  "          value=lookup('file', '%s/%s' | format(scan_root, file))",
  '        )',
  '  >     for key in dict_path_keys | reverse',
  '  >       set branch.value = {key: branch.value}',
  '  >     endfor',
  '  >     set result.value = result.value | combine(branch.value, recursive=True)',
  '  >   endif',
  '  > endfor',
  '  {{ result.value }}',
  'next_key:',
  '  list:',
  '    - 1',
  '    - 2',
}
local indent = require 'yaml_indent'
for _, ft in ipairs { 'yaml', 'yaml.ansible' } do
  vim.cmd 'enew!'
  vim.bo.filetype = ft
  vim.bo.shiftwidth = 2
  assert(vim.bo.indentexpr:find('yaml_indent', 1, true), 'wrapper loads for ' .. ft)
  local native = vim.b.yaml_indent_original
  indent.setup()
  assert(vim.b.yaml_indent_original == native, 'setup idempotent')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, sample)
  keys('gg=G')
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), sample), ft .. ': full example must retain indentation')
  for row = 24, #sample do
    assert(indent.indent(row) == vim.fn.eval((native:gsub('v:lnum', tostring(row)))), 'ordinary YAML delegates to native handler')
  end
  -- Type a dictionary colon in the middle of Jinja, without losing YAML indentation.
  vim.api.nvim_buf_set_lines(0, 17, 18, false, {'  >       set branch.value = {key branch.value}'})
  local line = vim.fn.getline(18)
  vim.api.nvim_win_set_cursor(0, {18, assert(line:find('key branch', 1, true)) + 2})
  keys('i:<Esc>')
  assert(vim.fn.getline(18) == sample[18], 'typing a colon must preserve manual indent')
  -- Enter after { must not apply YAML flow-map indentation to embedded code.
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {'value: |-', '  > set result = {'})
  vim.api.nvim_win_set_cursor(0, {2, 0})
  keys('oitem<CR>next<Esc>')
  assert(vim.fn.getline(3) == '  item' and vim.fn.getline(4) == '  next', 'Enter preserves block content indent')
  -- Blank block content initially inherits YAML indentation, including explicit indicators.
  for _, marker in ipairs { '|', '|-', '|+', '>', '>-', '>+', '|4-', '|-4' } do
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {'value: ' .. marker})
    vim.api.nvim_win_set_cursor(0, {1, 0})
    keys('otext<Esc>')
    local expected = marker:find('4', 1, true) and '    text' or '  text'
    assert(vim.fn.getline(2) == expected, marker .. ': first content line')
  end
  for _, key in ipairs { [[don't: |-]], [['quoted key': |- # comment]], [[value: !vault |]], [[value: &anchor >-]] } do
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {key, '  text', '  > set value = {key: other}'})
    assert(indent.indent(3) == -1, 'tagged/quoted scalar: ' .. key)
  end
  -- Quoted strings that look like scalar headers do not create block context.
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {'value: "not a header: |-"', '  other: 1'})
  assert(indent.indent(2) == vim.fn.eval((native:gsub('v:lnum', '2'))), 'quoted header is ignored')
  print(ft .. ': PASS full Jinja example, colon/Enter, scalar markers, native YAML/list behavior, idempotence')
end
vim.cmd 'qa!'
