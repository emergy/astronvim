local M = {}
local configured = false

function M.setup(compilers)
  if configured then return end
  configured = true
  require("nvim-treesitter.install").compilers = compilers or { "cc", "gcc", "clang" }
  -- Старый установщик делит один cache dir между всеми заданиями и процессами.
  -- Отдельный каталог на каждый запуск исключает конфликт download/extract/move.
  -- tempname() использует временный каталог Neovim, очищаемый при выходе.
  require("nvim-treesitter.utils").get_cache_dir = function()
    local path = vim.fn.tempname()
    local ok, result = pcall(vim.fn.mkdir, path, "p", 448)
    if not ok or result ~= 1 then
      return nil, "Не удалось создать каталог сборки Tree-sitter: " .. path
    end
    return path
  end
end

return M
