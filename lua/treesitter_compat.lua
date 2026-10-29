local M = {}

local function single_nodes(captures)
  local nodes = {}
  for id, values in pairs(captures) do
    nodes[id] = type(values) == "table" and values[#values] or values
  end
  return nodes
end

function M.setup()
  if M.ready or vim.fn.has "nvim-0.12" == 0 then return end
  local query = vim.treesitter.query
  local original = { add_predicate = query.add_predicate, add_directive = query.add_directive }
  -- Neovim 0.12 убрал all=false. Старые обработчики ожидают один TSNode,
  -- поэтому воспроизводим прежнее преобразование только при их регистрации.
  for name, register in pairs(original) do
    query[name] = function(key, handler, opts)
      if type(opts) == "table" and opts.all == false then
        local legacy = handler
        handler = function(captures, ...) return legacy(single_nodes(captures), ...) end
        opts = vim.tbl_extend("force", opts, { all = true })
      end
      return register(key, handler, opts)
    end
  end
  package.loaded["nvim-treesitter.query_predicates"] = nil
  local ok, err = pcall(require, "nvim-treesitter.query_predicates")
  for name, register in pairs(original) do
    query[name] = register
  end
  if not ok then error(err) end
  local queries = require "nvim-treesitter.query"
  local prepared = queries.iter_prepared_matches
  queries.iter_prepared_matches = function(parsed, ...)
    local proxy = setmetatable({
      iter_matches = function(_, ...)
        local iterator = parsed:iter_matches(...)
        return function()
          local pattern, captures, metadata = iterator()
          return pattern, captures and single_nodes(captures), metadata
        end
      end,
    }, { __index = parsed })
    return prepared(proxy, ...)
  end
  M.ready = true
end

return M
