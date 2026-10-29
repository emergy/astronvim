local groups = {
  {
    title = "ФАЙЛЫ И ПОИСК",
    rows = {
      "SPC ff       найти файл",
      "SPC fw       искать текст в проекте",
      "SPC fo / fb  недавние файлы / буферы",
      "SPC e        дерево файлов",
      "SPC fa       файлы конфигурации Neovim",
    },
  },
  {
    title = "РЕДАКТИРОВАНИЕ",
    rows = {
      "SPC w        сохранить файл",
      "SPC c        закрыть буфер",
      "SPC /        комментарий (также Visual)",
      "D            удалить до конца без копирования",
      "u / Ctrl-r   отменить / повторить",
    },
  },
  {
    title = "ОКНА И НАВИГАЦИЯ",
    rows = {
      "Ctrl-Shift-h/j/k/l или Alt-стрелки: окно",
      "| / \\        разделить: вертикаль / горизонталь",
      "]b / [b      следующий / предыдущий буфер",
      "SPC j        перейти к строке по метке Hop",
      "Alt-z        развернуть окно / вернуть",
    },
  },
  {
    title = "ТЕРМИНАЛЫ",
    rows = {
      "F7           показать / скрыть терминал",
      "F8           выбрать терминал",
      "Ctrl-\\ Ctrl-n выйти в Normal mode",
      "Ctrl-u/d     листать вывод вверх / вниз",
      "G / i        к новому выводу / ввод команд",
    },
  },
  {
    title = "NEO-TREE: НАВИГАЦИЯ (В ОКНЕ ДЕРЕВА)",
    rows = {
      "SPC o        фокус: дерево / редактор",
      "Enter / h / l открыть / свернуть / раскрыть",
      "s / S / t    вертикаль / горизонталь / вкладка",
      "Backspace / . выше / корень в выбранной папке",
      "/ / H        поиск / скрытые файлы",
      "R / ? / q    обновить / помощь / закрыть",
      "C / z        свернуть узел / все каталоги",
      "[b / ]b      сменить источник дерева",
    },
  },
  {
    title = "NEO-TREE: ФАЙЛЫ (В ОКНЕ ДЕРЕВА)",
    rows = {
      "a / A        создать файл / каталог",
      "r / d        переименовать / удалить",
      "y / x / p    копировать / вырезать / вставить",
      "c / m        копировать / переместить по пути",
      "Y            выбрать формат копирования пути",
      "P            предпросмотр файла",
      "b            переименовать без расширения",
      "Ctrl-r       очистить очередь копирования",
    },
  },
  {
    title = "NEO-TREE: ПОИСК И ФИЛЬТРЫ",
    rows = {
      "/ / D        искать файл / каталог",
      "f / Ctrl-x   задать / сбросить фильтр",
      "#            нечёткая сортировка",
      "H            показать / скрыть скрытые",
      "[g / ]g      предыдущий / следующий Git-файл",
      "i            сведения о файле",
    },
  },
  {
    title = "NEO-TREE: СОРТИРОВКА И ВИД",
    rows = {
      "o            показать меню сортировки",
      "on / ot      по имени / типу",
      "os / om      по размеру / изменению",
      "oc           по времени создания",
      "og / od      по Git-статусу / диагностике",
      "e / O        автоширина / открыть системно",
    },
  },
  {
    title = "LSP И ДИАГНОСТИКА (ПРИ ПОДКЛЮЧЕНИИ LSP)",
    rows = {
      "gd / K       определение / документация",
      "SPC lr       переименовать символ",
      "SPC la       действия над кодом",
      "]d / [d      следующая / предыдущая диагностика",
      "SPC lf       форматировать буфер",
    },
  },
  {
    title = "СЕССИИ И СПРАВКА",
    rows = {
      "SPC Ss       сохранить сессию",
      "SPC Sf / Sl  выбрать / последняя сессия",
      "SPC fk       поиск всех сочетаний клавиш",
      "SPC fh       поиск по справке Neovim",
      "SPC          нажать и подождать: which-key",
    },
  },
}

local function cheat_sheet(self)
  local wide = self:size().width >= 100
  local lines = {}
  if wide then
    for i = 1, #groups, 2 do
      local left, right = groups[i], groups[i + 1]
      local function row(a, b)
        lines[#lines + 1] = a .. string.rep(" ", math.max(2, 48 - vim.fn.strdisplaywidth(a))) .. b
      end
      row(left.title, right.title)
      for j = 1, math.max(#left.rows, #right.rows) do row(left.rows[j] or "", right.rows[j] or "") end
      lines[#lines + 1] = ""
    end
  else
    for _, group in ipairs(groups) do
      lines[#lines + 1] = group.title
      vim.list_extend(lines, group.rows)
      lines[#lines + 1] = ""
    end
  end
  return { text = table.concat(lines, "\n"), padding = 1 }
end

local function quick_actions(self)
  local keys = vim.deepcopy(self.opts.preset.keys)
  local lines = { "БЫСТРЫЕ ДЕЙСТВИЯ НА ЭТОМ ЭКРАНЕ" }
  for i = 1, #keys, 2 do
    local left = keys[i].key .. "  " .. keys[i].desc
    local right = keys[i + 1].key .. "  " .. keys[i + 1].desc
    if self:size().width >= 65 then
      lines[#lines + 1] = left .. string.rep(" ", math.max(2, 34 - vim.fn.strdisplaywidth(left))) .. right
    else
      lines[#lines + 1] = left
      lines[#lines + 1] = right
    end
  end
  local items = { { text = table.concat(lines, "\n"), padding = 1 } }
  for _, key in ipairs(keys) do
    key.hidden = true
    items[#items + 1] = key
  end
  return items
end

---@type LazySpec
return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    opts.dashboard = {
      width = math.min(94, math.max(40, vim.o.columns - 4)),
      preset = {
        header = "AstroNvim · Памятка\nSPC = пробел · Alt = M · сочетания в Normal mode",
        keys = {
          { key = "f", desc = "Найти файл", action = "<Leader>ff" },
          { key = "w", desc = "Найти текст", action = "<Leader>fw" },
          { key = "n", desc = "Новый файл", action = "<Leader>n" },
          { key = "r", desc = "Недавние файлы", action = "<Leader>fo" },
          { key = "k", desc = "Все сочетания клавиш", action = "<Leader>fk" },
          { key = "t", desc = "Выбрать терминал", action = "<F8>" },
          { key = "s", desc = "Последняя сессия", action = "<Leader>Sl" },
          { key = "q", desc = "Выйти", action = ":confirm qall" },
        },
      },
      sections = {
        { section = "header", padding = 1 },
        cheat_sheet,
        quick_actions,
        { text = "SPC h — открыть эту памятку снова", align = "center" },
      },
    }
  end,
}
