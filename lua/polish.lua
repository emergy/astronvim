-- if true then return end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE

-- This will run last in the setup process and is a good place to configure
-- things like custom filetypes. This just pure lua so anything that doesn't
-- fit in the normal config locations above can go here

-- Set up custom filetypes
-- vim.filetype.add {
--   extension = {
--     foo = "fooscript",
--   },
--   filename = {
--     ["Foofile"] = "fooscript",
--   },
--   pattern = {
--     ["~/%.config/foo/.*"] = "fooscript",
--   },
-- }

vim.filetype.add {
  filename = {
    ["devcontainer.json"] = "json5",
  },
}

vim.filetype.add {
  pattern = {
    [".*%.yml"] = "yaml.ansible", -- .yml файлы будут определяться как Ansible
    [".*%.yaml"] = "yaml", -- .yaml файлы как обычный YAML
  },
}

-- vim.cmd [[autocmd BufRead,BufNewFile **/ansible-ng/**/*.yml set filetype=yaml.ansible]]
-- vim.cmd [[autocmd BufRead,BufNewFile **/.devcontainer/*.json set filetype=json5]]
--
-- -- Удобная справка справа (:help)
-- vim.cmd [[
--   autocmd FileType help wincmd L
--   autocmd FileType help wincmd 82|
-- ]]

-- Минимальное количество строк на экране, которые нужно сохранять выше и ниже курсора
-- vim.opt.scrolloff = 10

-- https://github.com/neovim/neovim/discussions/28010
-- if vim.env.SSH_CONNECTION ~= nil or vim.env.WEZTERM_EXECUTABLE ~= nil then
--   vim.o.clipboard = "unnamedplus"
--
--   local function paste()
--     if vim.env.WEZTERM_EXECUTABLE ~= nil then
--       local clipboard_content = vim.fn.system "wezterm cli get-clipboard --no-newline"
--       local lines = vim.fn.split(clipboard_content, "\n")
--       return { lines, "v" }
--     else
--       return {
--         vim.fn.split(vim.fn.getreg "", "\n"),
--         vim.fn.getregtype "",
--       }
--     end
--   end
--
--   local function wezterm_send_text(text)
--     -- Используем wezterm cli для отправки текста
--     vim.fn.system { "wezterm", "cli", "send-text", text }
--   end
--
--   vim.g.clipboard = {
--     name = "OSC 52",
--     copy = {
--       ["+"] = require("vim.ui.clipboard.osc52").copy "+",
--       ["*"] = require("vim.ui.clipboard.osc52").copy "*",
--     },
--     paste = {
--       ["+"] = paste,
--       ["*"] = paste,
--     },
--   }
-- end

if vim.env.SSH_CONNECTION ~= nil or vim.env.WEZTERM_EXECUTABLE ~= nil then
  vim.o.clipboard = "unnamedplus"

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
end
