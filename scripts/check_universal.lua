-- Запускать через полную конфигурацию с NVIM_UNIVERSAL_TEST=1 и отдельными XDG-каталогами.
vim.defer_fn(function()
  local ok, err = pcall(function()
    local platform = require "user_platform"
    assert(platform.testing, "smoke test requires NVIM_UNIVERSAL_TEST=1")
    for _, key in ipairs { "<F7>", "<F8>", "<Space>bb", "<Space>j", "<M-z>" } do
      assert(vim.fn.maparg(key, "n") ~= "", "missing key: " .. key)
    end
    assert(vim.fn.maparg("<M-z>", "t") ~= "", "terminal zoom mapping")
    assert(vim.fn.maparg("<F8>", "t") ~= "", "terminal picker mapping")
    for _, mode in ipairs { "n", "t" } do
      for _, key in ipairs { "H", "J", "K", "L" } do
        -- Neovim канонизирует Ctrl+Shift+J как Shift+NL при регистрации.
        local lhs = key == "J" and "<S-NL>" or "<C-S-" .. key .. ">"
        assert(vim.fn.maparg(lhs, mode) ~= "", "shifted navigation: " .. mode .. key)
      end
      for _, arrow in ipairs { "Left", "Down", "Up", "Right" } do
        assert(vim.fn.maparg("<M-" .. arrow .. ">", mode) ~= "", "Alt-arrow navigation: " .. mode .. arrow)
      end
      assert(vim.fn.maparg("<NL>", mode) == "", "newline must not navigate windows")
    end
    local lazy = require "lazy"
    local plugins = require("lazy.core.config").plugins
    local treesitter = require("lazy.core.plugin").values(plugins["nvim-treesitter"], "opts", false)
    assert(
      treesitter.auto_install == false and #treesitter.ensure_installed == 0,
      "smoke tests must not auto-install parsers"
    )
    lazy.load { plugins = { "toggleterm.nvim", "codex.nvim", "render-markdown.nvim", "hop.nvim", "blink.cmp" } }
    assert(
      require("render-markdown.state").get(vim.api.nvim_get_current_buf()).code.sign == false,
      "Markdown icon policy"
    )
    local codex = require "codex"
    local codex_opts = require("lazy.core.plugin").values(plugins["codex.nvim"], "opts", false)
    assert(codex_opts.autoinstall == false, "tests must not auto-install Codex")
    codex.setup { panel = true, width = 0.33, autoinstall = false, cmd = { vim.fn.exepath "sh", "-c", "cat" } }
    local editor = vim.api.nvim_get_current_win()
    codex.open()
    local panel = require("codex.state").win
    assert(vim.api.nvim_win_get_config(panel).relative == "", "Codex is a panel")
    assert(vim.api.nvim_win_get_width(panel) == math.floor(vim.o.columns * 0.33), "Codex width")
    codex.close()
    assert(vim.api.nvim_win_is_valid(editor), "editor survives closing Codex")
    vim.api.nvim_set_current_win(editor)
    require("terminal_sessions").select()
    vim.wait(100, function() return false end)
    vim.cmd.stopinsert()
    local terms = require "toggleterm.terminal"
    local first = terms.get_all()[1]
    assert(first and first:is_open() and first.direction == "horizontal", "horizontal terminal opens")
    assert(vim.api.nvim_win_get_height(first.window) == 20, "terminal default height")
    local slot = first.window
    local second = terms.Terminal:new { direction = "vertical" }
    second:spawn()
    local select = vim.ui.select
    vim.ui.select = function(items, _, callback)
      for index, term in ipairs(items) do
        if term == second then
          callback(term, index)
          return
        end
      end
    end
    require("terminal_sessions").select()
    vim.ui.select = select
    assert(second.window == slot and second:is_open() and not first:is_open(), "terminal switching reuses split")
    for _, term in ipairs(terms.get_all()) do
      term:shutdown()
    end
    vim.cmd.stopinsert()
    vim.cmd "enew"
    vim.bo.filetype = "yaml.ansible"
    vim.wait(200, function() return false end)
    assert(vim.bo.indentexpr:find("yaml_indent", 1, true), "Ansible scalar indent wrapper")
    local ls = require "luasnip"
    require("luasnip.loaders.from_snipmate").lazy_load()
    local found = false
    for _, snippet in ipairs(ls.get_snippets "ansible") do
      if snippet.trigger == "jinja2" then found = true end
    end
    assert(found, "Ansible jinja2 snippet")
    local config = require "which-key.config"
    assert(not config.filter { lhs = "[и", desc = "duplicate" }, "Cyrillic mapping hidden")
    assert(config.filter { lhs = "[b", desc = "Previous buffer" }, "English mapping retained")
    if platform.system_tools then
      local plugins = require("lazy.core.config").plugins
      assert(not plugins["mason.nvim"], "Mason disabled for system-managed tools")
      local blink = require("lazy.core.plugin").values(plugins["blink.cmp"], "opts", false)
      assert(blink.fuzzy.implementation == "lua", "Mobile profiles use Lua fuzzy matching")
      assert(require("blink.cmp.fuzzy").implementation_type == "lua", "Lua fuzzy backend actually initialized")
    end
    print "PASS: full configuration, keymaps, Markdown, Codex panel, terminals, Ansible snippets/indent, Which-key, platform policy"
  end)
  if ok then
    vim.cmd "qa!"
  else
    print("FAIL: " .. tostring(err))
    vim.cmd "cquit 1"
  end
end, 1200)
