local config = vim.fn.stdpath "config"
local plugins = vim.fn.stdpath "data" .. "/lazy/"
vim.opt.runtimepath:prepend(config)
vim.opt.runtimepath:append(config .. "/after")
for _, name in ipairs { "ansible-vim", "nvim-treesitter" } do
  assert(vim.fn.isdirectory(plugins .. name) == 1, "Missing installed plugin: " .. name)
  vim.opt.runtimepath:prepend(plugins .. name)
end

local spec = dofile(config .. "/lua/plugins/treesitter.lua")
require("nvim-treesitter.configs").setup {
  ensure_installed = {},
  auto_install = false,
  indent = { enable = true, disable = spec.opts.indent.disable },
}
vim.cmd "filetype indent on"

local function insert(text)
  local keys = vim.api.nvim_replace_termcodes("i" .. text .. "<Esc>", true, false, true)
  vim.api.nvim_feedkeys(keys, "nx", false)
end

for _, ft in ipairs { "yaml", "yaml.ansible" } do
  vim.cmd "enew!"
  vim.bo.filetype = ft
  vim.bo.shiftwidth = 2
  local expected = ft == "yaml" and "GetYAMLIndent(v:lnum)" or "GetAnsibleIndent(v:lnum)"
  assert(vim.bo.indentexpr == expected, ft .. ": unexpected indentexpr: " .. vim.bo.indentexpr)
  local keys = vim.opt_local.indentkeys:get()
  for _, key in ipairs { "0-", "-", "<:>" } do
    assert(not vim.tbl_contains(keys, key), ft .. ": unexpected trigger: " .. key)
  end
  assert(vim.tbl_contains(keys, "o"), ft .. ": o indentation must remain enabled")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "list:", "  - 1", "  - 2" })
  assert(vim.fn.GetYAMLIndent(2) == 2 and vim.fn.GetYAMLIndent(3) == 2, ft .. ": list indentation")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "  pre_tasks:",
    "    - name: Gather package facts",
    "      ansible.builtin.include_tasks:",
    "        filetasks/package_facts.yml",
    "      tags:",
    "        - package_facts",
    "        common_networking",
  })
  vim.api.nvim_win_set_cursor(0, { 4, 12 })
  insert ":"
  assert(vim.api.nvim_buf_get_lines(0, 3, 4, false)[1] == "        file:tasks/package_facts.yml", ft .. ": colon changed indentation")
  vim.api.nvim_win_set_cursor(0, { 7, 8 })
  insert "- "
  assert(vim.api.nvim_buf_get_lines(0, 6, 7, false)[1] == "        - common_networking", ft .. ": dash changed indentation")
  print(ft .. ": PASS")
end
