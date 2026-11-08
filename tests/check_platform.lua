vim.opt.runtimepath:prepend(vim.fn.getcwd())
local saved = {}
local environment = { "PREFIX", "TERMUX_VERSION", "NVIM_UNIVERSAL_TEST", "NVIM_PROFILE", "HOME" }
for _, name in ipairs(environment) do
  saved[name] = vim.env[name]
end
for _, case in ipairs {
  { name = "Linux", home = "/home/test", prefix = "/usr", termux = false, nix = false },
  {
    name = "Termux",
    home = "/data/data/com.termux/files/home",
    prefix = "/data/data/com.termux/files/usr",
    termux = true,
    nix = false,
  },
  {
    name = "Nix Launcher",
    home = "/data/data/com.termux.launcher.nix/files/home",
    prefix = "",
    termux = false,
    nix = true,
  },
  { name = "Nix-on-Droid", home = "/data/data/com.termux.nix/files/home", prefix = "", termux = false, nix = true },
  {
    name = "Explicit Nix profile",
    home = "/home/test",
    prefix = "/data/data/com.termux/files/usr",
    profile = "nix-on-droid",
    termux = false,
    nix = true,
  },
} do
  vim.env.HOME, vim.env.PREFIX = case.home, case.prefix
  vim.env.TERMUX_VERSION, vim.env.NVIM_UNIVERSAL_TEST = nil, nil
  vim.env.NVIM_PROFILE = case.profile
  package.loaded.user_platform = nil
  local platform = require "user_platform"
  local mobile = case.termux or case.nix
  assert(platform.termux == case.termux and platform.nix_on_droid == case.nix, case.name .. ": platform detection")
  assert(platform.mobile == mobile and platform.system_tools == mobile, case.name .. ": tool policy")
  if case.nix then
    local path = vim.env.PATH
    platform.setup_path()
    assert(vim.env.PATH == path, "Nix must not inherit Termux tool directories")
  end
  local names, config = platform.available_servers()
  for _, name in ipairs(names) do
    assert(vim.fn.executable(config[name].cmd[1]) == 1, "server executable resolution")
  end
  local plugins = dofile "lua/plugins/portable.lua"
  local by_name = {}
  for _, plugin in ipairs(plugins) do
    by_name[plugin[1]] = plugin
  end
  assert((by_name["williamboman/mason.nvim"] ~= nil) == mobile, "system-managed tool policy")
  local opts = { fuzzy = { implementation = "prefer_rust" } }
  by_name["Saghen/blink.cmp"].opts(nil, opts)
  assert(opts.fuzzy.implementation == (mobile and "lua" or "prefer_rust"), "fuzzy library policy")
  print(case.name .. ": PASS platform detection and plugin policy")
end
for _, name in ipairs(environment) do
  vim.env[name] = saved[name]
end
vim.cmd "qa!"
