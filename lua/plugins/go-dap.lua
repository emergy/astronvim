return {
  "mfussenegger/nvim-dap",
  config = function()
    local dap = require "dap"

    dap.adapters.go = {
      type = "server",
      port = "${port}",
      executable = {
        command = "dlv",
        args = { "dap", "-l", "127.0.0.1:${port}" },
      },
    }

    dap.configurations.go = {
      {
        type = "go",
        name = "Debug with args",
        request = "launch",
        program = "${file}",
        args = { "search", "test" },
      },
    }
  end,
}
