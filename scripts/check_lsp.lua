vim.defer_fn(function()
  local ok, err = pcall(function()
    local project = assert(vim.env.NVIM_TEST_PROJECT, "NVIM_TEST_PROJECT required")
    local tests = {
      { name = "lua_ls", ft = "lua", file = project .. "/test.lua", text = "local value = 1" },
      { name = "yamlls", ft = "yaml", file = project .. "/test.yaml", text = "value: 1" },
      { name = "ansiblels", ft = "yaml.ansible", file = project .. "/playbooks/test.yml", text = "- hosts: all" },
      { name = "basedpyright", ft = "python", file = project .. "/test.py", text = "value = 1" },
    }
    for _, case in ipairs(tests) do
      vim.cmd "enew"
      vim.api.nvim_buf_set_name(0, case.file)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { case.text })
      vim.bo.filetype = case.ft
      local buf = vim.api.nvim_get_current_buf()
      if case.name == "ansiblels" then
        local config = require("astrolsp").config.config.ansiblels
        config.settings.ansible.ansibleLint.enabled = false
      end
      local attached
      assert(
        vim.wait(20000, function()
          for _, client in ipairs(vim.lsp.get_clients { bufnr = buf }) do
            if client.name == case.name and client.initialized then
              attached = client
              return true
            end
          end
          return false
        end, 50),
        "LSP did not initialize: " .. case.name
      )
      print("PASS: LSP " .. case.name .. " initialized and attached")
      vim.bo.modified = false
      vim.lsp.stop_client(attached.id, true)
    end
  end)
  if ok then
    vim.cmd "qa!"
  else
    print("FAIL: " .. tostring(err))
    vim.cmd "cquit 1"
  end
end, 1200)
