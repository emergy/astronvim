-- Component test: installed native parsers/plugins only; no Lazy/Mason setup.
local ok, err = pcall(function()
  local root = vim.env.NVIM_AERIAL_CONFIG or vim.fn.stdpath "config"
  vim.opt.rtp:prepend(root)
  local lazy = vim.fn.stdpath "data" .. "/lazy/"
  vim.opt.rtp:append(lazy .. "nvim-treesitter")
  vim.opt.rtp:append(lazy .. "aerial.nvim")
  local compat = require "treesitter_compat"
  compat.setup()
  pcall(require, "nvim-treesitter.query_predicates")
  local spec_path = root .. "/lua/plugins/aerial.lua"
  if vim.fn.filereadable(spec_path) == 1 then
    dofile(spec_path).opts()
  elseif compat.setup_aerial then
    compat.setup_aerial()
  end
  local helpers = require "aerial.backends.treesitter.helpers"
  local get_query = helpers.get_query
  if compat.setup_aerial then compat.setup_aerial() end
  assert(helpers.get_query == get_query, "Aerial compatibility must be idempotent")
  require("aerial.config").setup { backends = { "treesitter" }, filter_kind = false, nerd_font = false }
  local backend = require "aerial.backends.treesitter"
  local function symbols(lang, lines)
    vim.cmd.enew()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.bo.filetype = lang
    backend.fetch_symbols_sync(0)
    local data = require("aerial.data").get_or_create(0)
    assert(data:count() >= 2, lang .. " outline is empty")
    for _, item in ipairs(data.flat_items) do
      assert(type(item.lnum) == "number" and type(item.col) == "number", "invalid symbol range")
    end
    return data
  end
  local yaml = symbols("yaml", { "services:", "  api:", "    port: 8080", "  worker:", "    enabled: true" })
  assert(yaml.items[1].name == "services" and yaml.items[1].lnum == 1, "YAML parent range")
  local updates = 0
  local config = require "aerial.config"
  config.post_add_all_symbols = function(_, items) updates = updates + 1; return items end
  backend.fetch_symbols(vim.api.nvim_get_current_buf())
  assert(vim.wait(1000, function() return updates > 0 end), "async YAML outline update")
  config.post_add_all_symbols = nil
  local lua = symbols("lua", { "-- functions", "local function first()", "  return 1", "end", "local function second()", "  return 2", "end" })
  assert(lua.flat_items[1].name == "first" and lua.flat_items[2].name == "second", "Lua symbols")
  local modern = vim.treesitter.query.parse("lua", "(identifier) @id")
  local tree = vim.treesitter.get_parser(0, "lua"):parse()[1]
  local _, captures = modern:iter_matches(tree:root(), 0, 0, -1, { all = true })()
  assert(captures and type(captures[1]) == "table", "modern capture arrays must remain unchanged")
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  require("aerial.navigation").next()
  assert(vim.api.nvim_win_get_cursor(0)[1] == 2, "first function navigation")
  require("aerial.navigation").next()
  assert(vim.api.nvim_win_get_cursor(0)[1] == 5, "next function navigation")
  local parser = vim.treesitter.get_string_parser("# Example\n\n```lua\nlocal function nested() end\n```\n", "markdown")
  parser:parse(true)
  local languages = {}
  parser:for_each_tree(function(_, tree) languages[tree:lang()] = true end)
  assert(languages.markdown and languages.lua, "Markdown Lua injection")
  print("PASS Aerial sync/async YAML/Lua, function navigation, Markdown injection and modern captures; Neovim " .. tostring(vim.version()))
end)
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd "cquit 1"
end
vim.cmd "qa!"
