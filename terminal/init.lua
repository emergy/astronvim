-- Отдельная точка входа: AstroNvim/Lazy не загружаются.
local source = debug.getinfo(1, "S").source:sub(2)
local root = vim.fs.dirname(vim.fs.dirname(source))
vim.opt.rtp:prepend(root)
require("terminal_profile").setup()
