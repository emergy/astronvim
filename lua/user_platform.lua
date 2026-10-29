local M = {}

local prefix = vim.env.PREFIX or ""
M.termux = prefix:find("/com.termux/", 1, true) ~= nil or vim.env.TERMUX_VERSION ~= nil
M.testing = vim.env.NVIM_UNIVERSAL_TEST == "1"
M.system_tools = M.termux

function M.setup_path()
  if not M.termux then return end
  local tools = vim.fn.stdpath "data" .. "/tools"
  vim.env.PATH = tools .. "/bin:" .. tools .. "/node_modules/.bin:" .. (vim.env.PATH or "")
end

local servers = {
  ansiblels = { "ansible-language-server", "--stdio" },
  basedpyright = { "basedpyright-langserver", "--stdio" },
  bashls = { "bash-language-server", "start" },
  dockerls = { "docker-langserver", "--stdio" },
  helm_ls = { "helm_ls", "serve" },
  jsonls = { "vscode-json-language-server", "--stdio" },
  lua_ls = { "lua-language-server" },
  marksman = { "marksman", "server" },
  terraformls = { "terraform-ls", "serve" },
  yamlls = { "yaml-language-server", "--stdio" },
}

function M.available_servers()
  local names, config = {}, {}
  for name, command in pairs(servers) do
    local executable = vim.fn.exepath(command[1])
    if executable ~= "" then
      names[#names + 1] = name
      local cmd = vim.deepcopy(command)
      cmd[1] = executable
      config[name] = { cmd = cmd }
    end
  end
  table.sort(names)
  return names, config
end

return M
