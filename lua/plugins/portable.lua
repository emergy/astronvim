local platform = require "user_platform"

---@type LazySpec
local plugins = {
  {
    "zbirenbaum/copilot.lua",
    -- Закреплённый сервер содержит нативный policy-watcher без Android-бинарника.
    enabled = not platform.termux,
  },
  {
    "Saghen/blink.cmp",
    opts = function(_, opts)
      if platform.termux then
        -- Lua работает без загрузки glibc-библиотеки и без установки Rust.
        opts.fuzzy = vim.tbl_deep_extend("force", opts.fuzzy or {}, { implementation = "lua" })
      end
    end,
  },
  {
    "AstroNvim/astrolsp",
    opts = function(_, opts)
      if platform.system_tools then
        local servers, config = platform.available_servers()
        opts.servers = servers
        opts.config = vim.tbl_deep_extend("force", opts.config or {}, config)
      end
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if platform.testing then
        opts.auto_install = false
        opts.ensure_installed = {}
      end
    end,
  },
}

if platform.system_tools then
  for _, plugin in ipairs {
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
    "jay-babu/mason-null-ls.nvim",
    "jay-babu/mason-nvim-dap.nvim",
    "WhoIsSethDaniel/mason-tool-installer.nvim",
  } do
    plugins[#plugins + 1] = { plugin, enabled = false }
  end
  plugins[#plugins + 1] = {
    "nvimtools/none-ls.nvim",
    opts = function(_, opts)
      local null_ls = require "null-ls"
      local sources = {}
      for source, executable in pairs { stylua = "stylua", black = "black", isort = "isort", prettier = "prettier" } do
        if vim.fn.executable(executable) == 1 then sources[#sources + 1] = null_ls.builtins.formatting[source] end
      end
      opts.sources = require("astrocore").list_insert_unique(opts.sources, sources)
    end,
  }
end

if platform.testing and not platform.termux then
  for _, plugin in ipairs {
    "williamboman/mason-lspconfig.nvim",
    "jay-babu/mason-null-ls.nvim",
    "jay-babu/mason-nvim-dap.nvim",
    "WhoIsSethDaniel/mason-tool-installer.nvim",
  } do
    plugins[#plugins + 1] = {
      plugin,
      opts = function(_, opts)
        opts.ensure_installed = {}
        opts.automatic_installation = false
        opts.run_on_start = false
      end,
    }
  end
end

return plugins
