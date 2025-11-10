-- https://github.com/Wansmer/langmapper.nvim
return {
  {
    "Wansmer/langmapper.nvim",
    lazy = false, -- грузим рано
    priority = 1000, -- раньше прочих плагинов, чтобы перехватить keymap'ы
    init = function()
      -- 1) Статически задаём langmap (без внешних детекторов)
      -- РЕКОМЕНДОВАННЫЙ способ из README: строим пары по двум строкам (base/shift)
      local function escape(str)
        -- Эти символы нужно экранировать внутри langmap
        local escape_chars = [[;,."|\]]
        return vim.fn.escape(str, escape_chars)
      end

      -- Базовые ряды (EN ←→ RU)
      local en = [[`qwertyuiop[]asdfghjkl;'zxcvbnm]]
      local ru = [[ёйцукенгшщзхъфывапролджэячсмить]]
      local en_shift = [[~QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>]]
      local ru_shift = [[ËЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ]]

      -- Формируем корректную строку langmap вида "to;from,to;from"
      vim.opt.langmap = vim.fn.join({
        escape(ru_shift) .. ";" .. escape(en_shift),
        escape(ru) .. ";" .. escape(en),
      }, ",")
      -- Готово: теперь «движение» в normal/оператор-режимах будет работать на RU-раскладке.

      -- Leader должен быть определён до setup(), но в AstroNvim он уже " " по умолчанию.
      vim.g.mapleader = vim.g.mapleader or " "
      vim.g.maplocalleader = vim.g.maplocalleader or " "
    end,
    config = function()
      -- 2) Включаем langmapper: перевод всех keymap'ов (в т.ч. lazy-загружаемых)
      require("langmapper").setup {
        hack_keymap = true, -- оборачиваем vim.keymap.set, чтобы автопереводить бинды
        map_all_ctrl = true, -- сгенерировать Ctrl-варианты тоже
        disable_hack_modes = { "i" }, -- не трогаем insert-mode при хаке (обычно так удобнее)
        -- default_layout и use_layouts можно не трогать: у нас статическое langmap, обойдёмся без детекции
      }

      -- 3) Автоперевод уже объявленных маппингов после загрузки всех плагинов
      -- В AstroNvim корректнее повесить на VeryLazy:
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        callback = function() require("langmapper").automapping { global = true, buffer = true } end,
      })
    end,
  },
}
