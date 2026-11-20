import json
import os
from pathlib import Path
import subprocess

def plugins(settings, target, state, record):
    env = dict(os.environ)
    # pynvim lives in a dedicated venv, not in the base image's Python packages.
    provider = Path("/usr/local/bin/astronvim-python")
    command = ["nvim", "--headless"]
    if provider.exists():
        command.extend(["--cmd", "let g:python3_host_prog='/usr/local/bin/astronvim-python'"])
    restore = '''
local ok = pcall(require, "lazy")
if not ok then
  vim.api.nvim_err_writeln("lazy.nvim did not initialize")
  vim.cmd("cquit 1")
end
vim.cmd("Lazy! restore")
if vim.v.errmsg ~= "" then vim.cmd("cquit 1") end
for _, plugin in pairs(require("lazy.core.config").plugins) do
  if not plugin._.installed then
    vim.api.nvim_err_writeln("Plugin missing: " .. plugin.name)
    vim.cmd("cquit 1")
  end
end
local mason_ok, registry = pcall(require, "mason-registry")
if mason_ok then
  -- Let startup timers enqueue installers, then wait instead of killing them on qa.
  vim.wait(1000, function() return false end, 100)
  local idle = vim.wait(600000, function()
    for _, package in ipairs(registry.get_all_packages()) do
      if package:is_installing() then return false end
    end
    return true
  end, 100)
  if not idle then
    vim.api.nvim_err_writeln("Mason installation did not finish within ten minutes")
    vim.cmd("cquit 1")
  end
end
'''
    command.extend(["-c", "lua " + restore, "-c", "qa"])
    subprocess.run(command, cwd=str(target), env=env, check=True, timeout=900)
    record["plugins_ready"] = True
    state.write_text(json.dumps(record, indent=2) + "\n")
