-- if true then return end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE

-- This will run last in the setup process.
-- This is just pure lua so anything that doesn't
-- fit in the normal config locations above can go here

-- vim.filetype.add {
--   filename = {
--     ["devcontainer.json"] = "json5",
--   },
-- }
--
-- vim.filetype.add {
--   pattern = {
--     [".*%.yml"] = "yaml.ansible", -- .yml файлы будут определяться как Ansible
--     [".*%.yaml"] = "yaml", -- .yaml файлы как обычный YAML
--   },
-- }

-- if vim.env.SSH_CONNECTION ~= nil or vim.env.WEZTERM_EXECUTABLE ~= nil then
-- vim.o.clipboard = "unnamedplus"

local function paste()
  return {
    vim.fn.split(vim.fn.getreg "", "\n"),
    vim.fn.getregtype "",
  }
end

vim.g.clipboard = {
  name = "OSC 52",
  copy = {
    ["+"] = require("vim.ui.clipboard.osc52").copy "+",
    ["*"] = require("vim.ui.clipboard.osc52").copy "*",
  },
  paste = {
    ["+"] = paste,
    ["*"] = paste,
  },
  -- paste = {
  --   ["+"] = require("vim.ui.clipboard.osc52").paste "+",
  --   ["*"] = require("vim.ui.clipboard.osc52").paste "*",
  -- },
}
-- end

-- Первый скролл над Neo-tree активирует дерево до прокрутки, сохраняя позицию при клике.
require("neotree_mouse").setup()

require("buffer_mouse").setup()
