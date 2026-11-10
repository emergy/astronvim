local uv = vim.uv or vim.loop
local vault_headers, cache_size = {}, 0

local function encrypted_file(path)
  if type(path) ~= "string" then return false end
  local stat = uv.fs_stat(path)
  if not stat or stat.type ~= "file" then return false end
  local stamp =
    table.concat({ stat.ino, stat.size, stat.mtime.sec, stat.mtime.nsec, stat.ctime.sec, stat.ctime.nsec }, ":")
  local cached = vault_headers[path]
  if cached and cached.stamp == stamp then return cached.encrypted end
  local encrypted = false
  local file = io.open(path, "rb")
  if file then
    local header = file:read(256) or ""
    file:close()
    encrypted = header:match "^%$ANSIBLE_VAULT;[^\r\n]+[\r\n]" ~= nil
  end
  if cache_size >= 2048 then
    vault_headers, cache_size = {}, 0
  end
  if not vault_headers[path] then cache_size = cache_size + 1 end
  vault_headers[path] = { stamp = stamp, encrypted = encrypted }
  return encrypted
end

local function vault_icon(icon, node, state)
  local provider = require("neo-tree.defaults").default_component_configs.icon.provider
  if provider then icon = provider(icon, node, state) or icon end
  if node.type == "file" and encrypted_file(node.path) then
    icon.text = ""
    icon.highlight = "DiagnosticWarn"
  end
  return icon
end

---@type LazySpec
return {
  "nvim-neo-tree/neo-tree.nvim",
  -- Автоматически открывать дерево слева при запуске без файлов и каталогов
  -- на стартовом экране или в пустом буфере. Сейчас отключено.
  -- Чтобы включить, раскомментируйте блок init ниже и перезапустите Neovim.
  -- init = function()
  --   if vim.fn.argc(-1) > 0 then return end
  --   vim.api.nvim_create_autocmd("User", {
  --     pattern = "VeryLazy",
  --     group = vim.api.nvim_create_augroup("user_neotree_startup", { clear = true }),
  --     once = true,
  --     callback = function()
  --       vim.schedule(function()
  --         local dashboard = vim.bo.filetype == "snacks_dashboard"
  --         local empty = vim.bo.buftype == ""
  --           and vim.api.nvim_buf_get_name(0) == ""
  --           and not vim.bo.modified
  --           and vim.api.nvim_buf_line_count(0) == 1
  --           and vim.api.nvim_get_current_line() == ""
  --         if dashboard or empty then
  --           require("neo-tree.command").execute { action = "show", source = "filesystem", position = "left" }
  --         end
  --       end)
  --     end,
  --   })
  -- end,
  opts = function(_, opts)
    opts = vim.tbl_deep_extend("force", opts, {
      -- :edit из дерева временно закрывает окно файла при перенаправлении буфера.
      -- Автовыход в этот момент завершает Neovim до повторного открытия файла.
      close_if_last_window = false,
      default_component_configs = { icon = { provider = vault_icon } },
      filesystem = {
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
        },
      },
    })
    opts.event_handlers = opts.event_handlers or {}
    table.insert(opts.event_handlers, {
      id = "user_neotree_root_key",
      event = "after_render",
      handler = function(state)
        if state.name ~= "filesystem" then return end
        local mapping = state.resolved_mappings and state.resolved_mappings["."]
        if not mapping or not vim.api.nvim_buf_is_valid(state.bufnr) then return end
        -- Русский дубль / -> . не должен перекрывать явное назначение точки.
        local langmapper = package.loaded.langmapper
        local set = langmapper and langmapper.original_buf_set_keymap or vim.api.nvim_buf_set_keymap
        set(state.bufnr, "n", ".", "", {
          callback = mapping.handler,
          desc = mapping.text,
          noremap = true,
          silent = true,
        })
      end,
    })
    return opts
  end,
  dependencies = {
    "smoka7/hop.nvim",
  },
}
