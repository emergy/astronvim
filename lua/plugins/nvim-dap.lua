-- return {
--   "mfussenegger/nvim-dap",
--   config = function()
--     local dap = require "dap"
--     dap.adapters.python = {
--       type = "executable",
--       command = "/usr/bin/python",
--       args = { "-m", "debugpy.adapter" },
--     }
--
--     dap.configurations.python = {
--       -- {
--       --   -- The first three options are required by nvim-dap
--       --   type = "python", -- the type here established the link to the adapter definition: `dap.adapters.python`
--       --   request = "launch",
--       --   name = "Launch file",
--       --
--       --   -- Options below are for debugpy, see https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings for supported options
--       --
--       --   program = "${file}", -- This configuration will launch the current file if used.
--       --   pythonPath = function()
--       --     -- debugpy supports launching an application with a different interpreter then the one used to launch debugpy itself.
--       --     -- The code below looks for a `venv` or `.venv` folder in the current directly and uses the python within.
--       --     -- You could adapt this - to for example use the `VIRTUAL_ENV` environment variable.
--       --     local cwd = vim.fn.getcwd()
--       --     if vim.fn.executable(cwd .. "/venv/bin/python") == 1 then
--       --       return cwd .. "/venv/bin/python"
--       --     elseif vim.fn.executable(cwd .. "/.venv/bin/python") == 1 then
--       --       return cwd .. "/.venv/bin/python"
--       --     else
--       --       return "/usr/bin/python"
--       --     end
--       --   end,
--       -- },
--       {
--         name = "Attach to process 10.10.47.9:5678",
--         type = "python",
--         request = "attach",
--         connect = {
--           -- type = "tcp",
--           host = "10.10.47.9",
--           port = 5678,
--         },
--         patchMappings = {
--           localRoot = "${workspaceFolder}/debug_dir",
--           remoteRoot = "/root/.ansible/tmp/ansible-tmp-1729859688.578952-8616-16874770863070/debug_dir",
--         },
--       },
--     }
--   end,
-- }

-- -- No configuration found for `python`. You need to add configs to `dap.configurations.python` (See `:h dap-configuration`)
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
          -- {
          --   name = "Launch file",
          --   type = "python",
          --   request = "launch",
          --   program = "${file}", -- This configuration will launch the current file if used.
          -- },
          -- {
          --   name = "Attach to process localhost:5678",
          --   type = "python",
          --   request = "attach",
          --   connect = {
          --     type = "tcp",
          --     host = "localhost",
          --     port = 5678,
          --   },
          -- },
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
    },
  },
}
