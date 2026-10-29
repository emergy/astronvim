vim.opt.rtp:prepend(vim.fn.getcwd())
local prefix, version, testing = vim.env.PREFIX, vim.env.TERMUX_VERSION, vim.env.NVIM_UNIVERSAL_TEST
for _, termux in ipairs { false, true } do
  vim.env.PREFIX = termux and "/data/data/com.termux/files/usr" or "/usr"
  vim.env.TERMUX_VERSION = nil
  vim.env.NVIM_UNIVERSAL_TEST = nil
  package.loaded.user_platform = nil
  local platform = require "user_platform"
  assert(platform.termux == termux, "platform detection")
  assert(platform.system_tools == termux, "tool policy")
  local names, config = platform.available_servers()
  for _, name in ipairs(names) do
    assert(vim.fn.executable(config[name].cmd[1]) == 1, "server executable resolution")
  end
  local plugins = dofile "lua/plugins/portable.lua"
  local by_name = {}
  for _, plugin in ipairs(plugins) do
    by_name[plugin[1]] = plugin
  end
  assert((by_name["williamboman/mason.nvim"] ~= nil) == termux, "Mason disabled only in Termux")
  local opts = { fuzzy = { implementation = "prefer_rust" } }
  by_name["Saghen/blink.cmp"].opts(nil, opts)
  assert(opts.fuzzy.implementation == (termux and "lua" or "prefer_rust"), "native fuzzy library policy")
  print((termux and "Termux" or "Linux") .. ": PASS platform detection and plugin policy")
end
vim.env.PREFIX, vim.env.TERMUX_VERSION, vim.env.NVIM_UNIVERSAL_TEST = prefix, version, testing
vim.cmd "qa!"
