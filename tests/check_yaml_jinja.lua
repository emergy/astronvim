-- nvim --headless -u NONE -i NONE -l tests/check_yaml_jinja.lua
local root = vim.fn.getcwd()
vim.opt.rtp:prepend(root)
vim.opt.rtp:append(root .. "/after")
for _, name in ipairs { "ansible-vim", "nvim-treesitter" } do
  vim.opt.rtp:append(vim.fn.stdpath "data" .. "/lazy/" .. name)
end
local spec = dofile(root .. "/lua/plugins/yaml_jinja.lua")
vim.filetype.add(spec[1].opts.filetypes)
spec[2].init()
local opts = { highlight = { enable = true, disable = { "vim" } }, auto_install = false, ensure_installed = {} }
spec[3].opts(nil, opts)
require("treesitter_compat").setup()
require("nvim-treesitter.configs").setup(opts)
vim.cmd "filetype plugin indent on"
vim.cmd "syntax enable"
local sample = {
  "job:",
  '  image: "{{ image | lower }}"',
  "{% if enabled %}",
  "  retries: 3",
  "{% endif %}",
  "{# comment #}",
}
local function groups(row)
  local result = {}
  for col = 1, #sample[row] do
    result[vim.fn.synIDattr(vim.fn.synID(row, col, 1), "name")] = true
  end
  return result
end
for _, name in ipairs { ".gitlab-ci.yml.j2", "config.yaml.j2", "roles/demo/templates/main.yml.j2" } do
  vim.cmd.enew { bang = true }
  vim.api.nvim_buf_set_name(0, root .. "/.tmp/yaml-jinja-fixture/" .. name)
  vim.api.nvim_exec_autocmds("BufNewFile", { buffer = 0 })
  vim.api.nvim_buf_set_lines(0, 0, -1, false, sample)
  assert(vim.bo.filetype == "yaml.jinja2", name .. ": filetype " .. vim.bo.filetype)
  assert(groups(1).yamlBlockMappingKey and groups(4).yamlInteger, name .. ": YAML highlighting")
  assert(groups(2).jinjaVariable and groups(2).jinjaFilter, name .. ": Jinja expressions/filters")
  assert(groups(3).jinjaStatement and groups(5).jinjaStatement, name .. ": Jinja control blocks")
  assert(groups(6).jinjaComment, name .. ": Jinja comments")
  assert(not vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()], "YAML parser masked Jinja")
end
vim.cmd.enew { bang = true }
vim.api.nvim_buf_set_name(0, root .. "/.tmp/yaml-jinja-fixture/plain.yml")
vim.api.nvim_exec_autocmds("BufNewFile", { buffer = 0 })
assert(vim.bo.filetype == "yaml", "plain YAML filetype changed")
assert(not opts.highlight.disable("yaml", 0), "plain YAML Tree-sitter disabled")
assert(opts.highlight.disable("vim", 0), "existing Tree-sitter exclusion lost")
vim.api.nvim_buf_set_name(0, root .. "/.tmp/yaml-jinja-fixture/plain.txt.j2")
vim.bo.filetype = ""
vim.api.nvim_exec_autocmds("BufNewFile", { buffer = 0 })
assert(vim.bo.filetype == "jinja2", "other Jinja templates changed")
local inherited = function(lang) return lang == "lua" end
local other = { highlight = { disable = inherited } }
spec[3].opts(nil, other)
assert(other.highlight.disable("lua", 0) and not other.highlight.disable("yaml", 0), "disable callback lost")
print "PASS: YAML/Jinja filetypes, keys/numbers, expressions/filters, control blocks/comments; ordinary files preserved"
