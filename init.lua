-- This file simply bootstraps the installation of Lazy.nvim and then calls other files for execution
-- This file doesn't necessarily need to be touched, BE CAUTIOUS editing this file and proceed at your own risk.
local lazypath = vim.env.LAZY or vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
if not (vim.env.LAZY or (vim.uv or vim.loop).fs_stat(lazypath)) then
  -- stylua: ignore
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- validate that lazy is available
if not pcall(require, "lazy") then
  -- stylua: ignore
  vim.api.nvim_echo({ { ("Unable to load lazy from: %s\n"):format(lazypath), "ErrorMsg" }, { "Press any key to exit...", "MoreMsg" } }, true, {})
  vim.fn.getchar()
  vim.cmd.quit()
end

require "lazy_setup"
require "polish"

-- require("devcontainer").setup{}

-- Русская раскладка → Английская раскладка
vim.keymap.set("n", "й", ":") -- ':' для командного режима
vim.keymap.set("n", "ц", "q")
vim.keymap.set("n", "у", "e")
vim.keymap.set("n", "к", "r")
vim.keymap.set("n", "е", "t")
vim.keymap.set("n", "н", "y")
vim.keymap.set("n", "г", "u")
vim.keymap.set("n", "ш", "i")
vim.keymap.set("n", "щ", "o")
vim.keymap.set("n", "з", "p")
vim.keymap.set("n", "х", "[")
vim.keymap.set("n", "ъ", "]")

vim.keymap.set("n", "ф", "a")
vim.keymap.set("n", "ы", "s")
vim.keymap.set("n", "в", "d")
vim.keymap.set("n", "а", "f")
vim.keymap.set("n", "п", "g")
vim.keymap.set("n", "р", "h")
vim.keymap.set("n", "о", "j")
vim.keymap.set("n", "л", "k")
vim.keymap.set("n", "д", "l")
vim.keymap.set("n", "ж", ";")
vim.keymap.set("n", "э", "'")

vim.keymap.set("n", "я", "z")
vim.keymap.set("n", "ч", "x")
vim.keymap.set("n", "с", "c")
vim.keymap.set("n", "м", "v")
vim.keymap.set("n", "и", "b")
vim.keymap.set("n", "т", "n")
vim.keymap.set("n", "ь", "m")
vim.keymap.set("n", "б", ",")
vim.keymap.set("n", "ю", ".")
vim.keymap.set("n", ".", "/")

-- Верхний регистр (Shift + Русская буква → Английская)
vim.keymap.set("n", "Й", ":") -- ':' для командного режима (с Shift)
vim.keymap.set("n", "Ц", "Q")
vim.keymap.set("n", "У", "E")
vim.keymap.set("n", "К", "R")
vim.keymap.set("n", "Е", "T")
vim.keymap.set("n", "Н", "Y")
vim.keymap.set("n", "Г", "U")
vim.keymap.set("n", "Ш", "I")
vim.keymap.set("n", "Щ", "O")
vim.keymap.set("n", "З", "P")
vim.keymap.set("n", "Х", "{")
vim.keymap.set("n", "Ъ", "}")

vim.keymap.set("n", "Ф", "A")
vim.keymap.set("n", "Ы", "S")
vim.keymap.set("n", "В", "D")
vim.keymap.set("n", "А", "F")
vim.keymap.set("n", "П", "G")
vim.keymap.set("n", "Р", "H")
vim.keymap.set("n", "О", "J")
vim.keymap.set("n", "Л", "K")
vim.keymap.set("n", "Д", "L")
vim.keymap.set("n", "Ж", ":")
vim.keymap.set("n", "Э", '"')

vim.keymap.set("n", "Я", "Z")
vim.keymap.set("n", "Ч", "X")
vim.keymap.set("n", "С", "C")
vim.keymap.set("n", "М", "V")
vim.keymap.set("n", "И", "B")
vim.keymap.set("n", "Т", "N")
vim.keymap.set("n", "Ь", "M")
vim.keymap.set("n", "Б", "<")
vim.keymap.set("n", "Ю", ">")
vim.keymap.set("n", ",", "?")

-- Удаление из строки без копирования в буфер обмена
vim.api.nvim_set_keymap("n", "D", '"_D', { noremap = true, silent = true })
