---@type LazySpec
return {
  {
    "AstroNvim/astrolsp",
    opts = {
      config = {
        ansiblels = {
          root_dir = require("lspconfig.util").root_pattern(".ansible-lint", "ansible.cfg", ".git"),
          settings = { ansible = { ansibleLint = { arguments = "--offline" } } },
        },
      },
    },
  },

  {
    "jay-babu/mason-null-ls.nvim",
    opts = {
      handlers = {
        -- ansible-lint уже запускает ansible-language-server
        ansiblelint = function() end,
      },
    },
  },
}
