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
            name = "Attach to process 10.10.47.9:5678",
            type = "python",
            request = "attach",
            connect = {
              -- type = "tcp",
              host = "10.10.47.9",
              port = 5678,
            },
            pathMappings = function()
              local cwd = "${workspaceFolder}/debug_dir"
              local local_path = vim.fn.input("Local path mapping [" .. cwd .. "]: ")
              local_path = local_path ~= "" and local_path or cwd
              local remote_path = vim.fn.input "Remote path mapping [.]: "
              remote_path = remote_path ~= "" and remote_path or "."
              return { { localRoot = local_path, remoteRoot = remote_path } }
            end,
            -- patchMappings = {
            --   localRoot = "/workspaces/ansible-ng/ntvplus/nomad-cluster/debug_dir",
            --   remoteRoot = "/root/.ansible/tmp/ansible-tmp-1729864500.3576329-13720-48984962311531/debug_dir",
            -- },
          },
        }
      end,

      -- golang = function(source_name)
      --   local dap = require "dap"
      --
      --   dap.adapters.go = {
      --     type = "server",
      --     port = "${port}",
      --     executable = {
      --       command = "dlv",
      --       args = { "dap", "-l", "127.0.0.1:${port}" },
      --     },
      --   }
      --
      --   dap.configurations.go = {
      --     {
      --       type = "go",
      --       name = "Debug with args",
      --       request = "launch",
      --       program = "${file}",
      --       args = { "search", "test" }, -- замените "arg1", "arg2", "arg3" на нужные аргументы
      --     },
      --   }
      -- end,
    },
  },
}
