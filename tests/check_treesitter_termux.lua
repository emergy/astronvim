-- Явная проверка двух одновременных установок одного парсера в изолированном каталоге.
-- Требуются установленные nvim-treesitter, clang/cc и доступ к источникам парсера.
local root = vim.env.NVIM_TEST_CONFIG or vim.fn.getcwd()
local plugin = vim.env.NVIM_TEST_TREESITTER or (vim.fn.stdpath "data" .. "/lazy/nvim-treesitter")
vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(plugin)
require("treesitter_compat").setup()
local work = vim.fn.tempname()
assert(vim.fn.mkdir(work, "p", 448) == 1)
vim.opt.rtp = { root, plugin, work .. "/install", vim.env.VIMRUNTIME }
require("treesitter_termux").setup()
local installer = require "nvim-treesitter.install"
local selectors = require "nvim-treesitter.shell_command_selectors"
local downloads, compilers, completed = {}, {}, 0
local download = selectors.select_download_commands
selectors.select_download_commands = function(repo, project, cache, ...)
  downloads[#downloads + 1] = cache
  return download(repo, project, cache, ...)
end
local compile = selectors.select_compile_command
selectors.select_compile_command = function(repo, compiler, ...)
  compilers[#compilers + 1] = compiler
  return compile(repo, compiler, ...)
end
local iter = installer.iter_cmd
installer.iter_cmd = function(commands, index, ...)
  if index == #commands + 1 then completed = completed + 1 end
  return iter(commands, index, ...)
end
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[user]", "  name = Test", "  email = test@example.invalid" })
vim.bo.filetype = "gitconfig"
require("nvim-treesitter.configs").setup {
  parser_install_dir = work .. "/install",
  ensure_installed = {},
  auto_install = true,
  highlight = { enable = false },
}
vim.api.nvim_exec_autocmds("FileType", { pattern = "gitconfig" })
assert(#downloads == 2 and downloads[1] ~= downloads[2], "parallel installs need independent work dirs")
assert(vim.wait(90000, function() return completed == 2 end, 25), "both native builds must finish: " .. vim.v.errmsg)
assert(vim.v.errmsg == "", vim.v.errmsg)
assert(#compilers == 2 and compilers[1] == "clang" and compilers[2] == "clang", "native compiler selection")
assert(not vim.treesitter.get_parser(0, "git_config"):parse()[1]:root():has_error())
assert(vim.treesitter.query.get("git_config", "highlights"), "installed queries must load")
print "PASS: concurrent automatic git_config installs, isolated work dirs, native clang, parser and highlights"
