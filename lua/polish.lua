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
