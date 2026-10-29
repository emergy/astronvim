vim.defer_fn(function()
  local ok, err = pcall(function()
    for language, text in pairs {
      yaml = "value: 1",
      lua = "local value = 1",
      python = "value = 1",
      json = '{"value":1}',
      markdown = "# Title",
    } do
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })
      local tree = vim.treesitter.get_parser(buf, language):parse()[1]
      assert(not tree:root():has_error(), "native parser: " .. language)
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    vim.cmd "enew"
    vim.api.nvim_buf_set_lines(
      0,
      0,
      -1,
      false,
      { "local function first()", "  return 1", "end", "", "local function second()", "  return 2", "end" }
    )
    vim.bo.filetype = "lua"
    require("lazy").load { plugins = { "nvim-treesitter", "nvim-treesitter-textobjects" } }
    vim.treesitter.get_parser(0, "lua"):parse()
    local matches = require("nvim-treesitter.query").get_capture_matches(
      vim.api.nvim_get_current_buf(),
      "@function.outer",
      "textobjects"
    )
    assert(#matches == 2, "legacy Tree-sitter capture iteration: " .. #matches)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    require("nvim-treesitter.textobjects.move").goto_next_start("@function.outer", "textobjects")
    assert(vim.api.nvim_win_get_cursor(0)[1] == 5, "Tree-sitter next function motion")
    vim.bo.modified = false
    vim.cmd "enew"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# Title", "", "```yaml", "value: 1", "```", "", "End" })
    vim.bo.filetype = "markdown"
    vim.api.nvim_win_set_cursor(0, { 7, 0 })
    require("lazy").load { plugins = { "render-markdown.nvim" } }
    require("render-markdown").render { buf = vim.api.nvim_get_current_buf() }
    local found = false
    assert(
      vim.wait(3000, function()
        for name, ns in pairs(vim.api.nvim_get_namespaces()) do
          if name:find("render_markdown", 1, true) or name:find "render%-markdown" then
            for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })) do
              if mark[2] == 2 then
                assert(not mark[4].sign_text, "duplicate code language icon in sign column")
                for _, chunk in ipairs(mark[4].virt_text or {}) do
                  if chunk[1]:find("yaml", 1, true) then found = true end
                end
              end
            end
          end
        end
        return found
      end, 50),
      "Markdown code language header must render"
    )
    print "PASS: native parsers, Tree-sitter captures/function motion and real Markdown header without duplicate sign"
  end)
  if ok then
    vim.cmd "qa!"
  else
    print("FAIL: " .. tostring(err))
    vim.cmd "cquit 1"
  end
end, 1200)
