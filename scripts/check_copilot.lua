vim.defer_fn(function()
  local ok, err = pcall(function()
    if require("user_platform").termux then
      assert(not require("lazy.core.config").plugins["copilot.lua"], "unsupported Copilot backend must stay disabled")
      print "PASS: Termux excludes the unsupported Copilot backend"
      return
    end
    require("lazy").load { plugins = { "copilot.lua" } }
    local client = require "copilot.client"
    client.ensure_client_started()
    assert(
      vim.wait(15000, function()
        local running = client.get()
        return running and running.initialized
      end, 50),
      "Copilot language server did not initialize"
    )
    print "PASS: Copilot language server initialized; account authorization is separate"
  end)
  if ok then
    vim.cmd "qa!"
  else
    print("FAIL: " .. tostring(err))
    vim.cmd "cquit 1"
  end
end, 1200)
