-- if true then return {} end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE

-- AstroCore provides a central place to modify mappings, vim options, autocommands, and more!
-- Configuration documentation can be found with `:h astrocore`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    -- Configure core features of AstroNvim
    features = {
      large_buf = { size = 1024 * 256, lines = 10000 }, -- set global limits for large files for disabling features like treesitter
      autopairs = true, -- enable autopairs at start
      cmp = true, -- enable completion at start
      diagnostics = { virtual_text = true, virtual_lines = false }, -- diagnostic settings on startup
      highlighturl = true, -- highlight URLs at start
      notifications = true, -- enable notifications at start
    },
    -- Diagnostics configuration (for vim.diagnostics.config({...})) when diagnostics are on
    -- diagnostics = {
    --   virtual_text = true,
    --   underline = true,
    -- },
    diagnostics = { signs = true, underline = true, update_in_insert = false },
    -- passed to `vim.filetype.add`
    filetypes = {
      -- see `:h vim.filetype.add` for usage
      extension = {
        foo = "fooscript",
      },
      filename = {
        -- ["Foofile"] = "fooscript",
        ["devcontainer.json"] = "json5",
      },
      pattern = {
        -- [".*/etc/foo/.*"] = "fooscript",
        [".*%.yml"] = "yaml.ansible", -- .yml файлы будут определяться как Ansible
        [".*%.yaml"] = "yaml", -- .yaml файлы как обычный YAML
      },
    },
    -- vim options can be configured here
    options = {
      opt = { -- vim.opt.<key>
        relativenumber = true, -- sets vim.opt.relativenumber
        number = true, -- sets vim.opt.number
        spell = false, -- sets vim.opt.spell
        signcolumn = "yes", -- sets vim.opt.signcolumn to yes
        wrap = false, -- sets vim.opt.wrap
        -- langmap = table.concat({
          -- -- нижний регистр
          -- "й:q,ц:w,у:e,к:r,е:t,н:y,г:u,ш:i,щ:o,з:p,х:[,ъ:]",
          -- "ф:a,ы:s,в:d,а:f,п:g,р:h,о:j,л:k,д:l,ж:;,э:'",
          -- "я:z,ч:x,с:c,м:v,и:b,т:n,ь:m,б:,,ю:.,.:/",
          -- -- верхний регистр
          -- "Й:Q,Ц:W,У:E,К:R,Е:T,Н:Y,Г:U,Ш:I,Щ:O,З:P,Х:{,Ъ:}",
          -- "Ф:A,Ы:S,В:D,А:F,П:G,Р:H,О:J,Л:K,Д:L,Ж::,Э:\"",
          -- "Я:Z,Ч:X,С:C,М:V,И:B,Т:N,Ь:M,Б:<,Ю:>,,:?",
        -- }, ","),
      },
      g = { -- vim.g.<key>
        -- configure global vim variables (vim.g)
        -- NOTE: `mapleader` and `maplocalleader` must be set in the AstroNvim opts or before `lazy.setup`
        -- This can be found in the `lua/lazy_setup.lua` file
        mapleader = " ", -- sets vim.g.mapleader
      },
    },
    -- Mappings can be configured through AstroCore as well.
    -- NOTE: keycodes follow the casing in the vimdocs. For example, `<Leader>` must be capitalized
    mappings = {
      -- first key is the mode
      n = {
        -- second key is the lefthand side of the map

        -- navigate buffer tabs
        ["]b"] = { function() require("astrocore.buffer").nav(vim.v.count1) end, desc = "Next buffer" },
        ["[b"] = { function() require("astrocore.buffer").nav(-vim.v.count1) end, desc = "Previous buffer" },

        -- mappings seen under group name "Buffer"
        ["<Leader>bd"] = {
          function()
            require("astroui.status.heirline").buffer_picker(
              function(bufnr) require("astrocore.buffer").close(bufnr) end
            )
          end,
          desc = "Close buffer from tabline",
        },

        -- tables with just a `desc` key will be registered with which-key if it's installed
        -- this is useful for naming menus
        -- ["<Leader>b"] = { desc = "Buffers" },

        -- setting a mapping to false will disable it
        -- ["<C-S>"] = false,
      },
    },
  },
}
