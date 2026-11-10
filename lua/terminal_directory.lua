local M = {}
local configured = false

function M.root()
  local manager = package.loaded["neo-tree.sources.manager"]
  if manager then
    local state = manager.get_state("filesystem", vim.api.nvim_get_current_tabpage())
    if state.path and vim.fn.isdirectory(state.path) == 1 then return state.path end
  end
  -- Локальный cwd редакторского окна может указывать на каталог последнего файла.
  return vim.fn.getcwd(-1, 0)
end

function M.setup()
  if configured then return end
  configured = true
  local Terminal = require("toggleterm.terminal").Terminal
  local new = Terminal.new
  Terminal.new = function(self, options)
    options = options or {}
    -- Явный dir (включая команды Neo-tree Th/Tv/Tf) всегда имеет приоритет.
    if options.dir == nil then options.dir = M.root() end
    return new(self, options)
  end
end

return M
