return {
  "jay-babu/mason-nvim-dap.nvim",
  opts = {
    handlers = {
      python = function(source_name)
        local dap = require "dap"
        dap.adapters.python = {
          type = "executable",
          command = "/usr/bin/python3",
          args = {
            "-m",
            "debugpy.adapter",
          },
        }

        dap.configurations.python = {
          {
            name = "Launch file",
            type = "python",
            request = "launch",
            program = "${file}", -- This configuration will launch the current file if used.
          },
          {
            name = "Attach to process localhost:5678",
            type = "python",
            request = "attach",
            connect = {
              type = "tcp",
              host = "localhost",
              port = 5678,
            },
          },
          {
            name = "Attach to process 10.10.47.9:5678",
            type = "python",
            request = "attach",
            connect = {
              type = "tcp",
              host = "10.10.47.9",
              port = 5678,
            },
          },
        }
      end,
    },
  },
}
