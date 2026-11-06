vim.opt.runtimepath:prepend(vim.fn.getcwd())
local uv = vim.uv or vim.loop
local root = vim.fn.getcwd() .. "/.tmp/ansible-vault-" .. uv.os_getpid()
vim.fn.mkdir(root, "p", 448)
local function put(path, data)
  local file = assert(io.open(path, "wb"))
  file:write(data)
  file:close()
  assert(uv.fs_chmod(path, 384))
end
local function get(path)
  local file = assert(io.open(path, "rb"))
  local data = file:read "*a"
  file:close()
  return data
end
local key = root .. "/test-key"
put(key, "synthetic-test-password\n")
put(root .. "/ansible.cfg", "[defaults]\n")
vim.env.ANSIBLE_CONFIG = root .. "/ansible.cfg"
vim.env.ANSIBLE_VAULT_PASSWORD_FILE = key
vim.env.ANSIBLE_VAULT_IDENTITY_LIST = nil
vim.env.ANSIBLE_VAULT_ENCRYPT_IDENTITY = nil
vim.env.ANSIBLE_ASK_VAULT_PASS = nil
local function crypto(action, text)
  local result = vim.system({ "ansible-vault", action, "--output", "-", "-" }, { stdin = text }):wait()
  assert(result.code == 0, result.stderr)
  return result.stdout
end
local original = "password: synthetic-secret\nnested:\n  enabled: true\n"
local path = root .. "/vault with spaces.yml"
local ciphertext = crypto("encrypt", original)
put(path, ciphertext)
assert(uv.fs_chmod(path, 416)) -- 0640
local notices = {}
vim.notify = function(message) notices[#notices + 1] = message end
vim.o.undofile = true
vim.o.undodir = root
vim.o.backup = true
vim.o.writebackup = true
vim.o.backupdir = root
require("ansible_vault").setup()
local function edit(name) vim.cmd("edit! " .. vim.fn.fnameescape(name)) end
local function text() return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n") end
local function change(value) vim.api.nvim_buf_set_lines(0, 0, -1, false, { "password: " .. value }) end
edit(path)
assert(text() .. "\n" == original, "automatic decrypt")
assert(
  vim.bo.buftype == "acwrite" and not vim.bo.swapfile and not vim.bo.undofile and not vim.bo.modeline,
  "buffer protection"
)
assert(not vim.bo.modified and get(path) == ciphertext, "opening must not write")
change "updated-test-secret"
vim.cmd.write()
assert(crypto("decrypt", get(path)) == "password: updated-test-secret\n", "save remains encrypted")
assert(not vim.bo.modified and bit.band(uv.fs_stat(path).mode, 511) == 416, "save state and permissions")
local saved = get(path)
vim.env.ANSIBLE_VAULT_PASSWORD_FILE = root .. "/missing-key"
change "must-stay-in-memory"
assert(not pcall(vim.cmd.write), "failed encryption must fail :write")
assert(
  get(path) == saved and vim.bo.modified and text():find("must-stay-in-memory", 1, true),
  "failed save preserves file and edits"
)
vim.env.ANSIBLE_VAULT_PASSWORD_FILE = key
local export = root .. "/must-not-export.yml"
assert(not pcall(vim.cmd, "1write " .. vim.fn.fnameescape(export)), "partial export blocked")
assert(not uv.fs_stat(export), "no plaintext export")
assert(not pcall(vim.cmd, "write " .. vim.fn.fnameescape(export)), "alternate write blocked")
assert(not uv.fs_stat(export), "no alternate plaintext file")
vim.cmd.write()
local wrong_key = root .. "/wrong-key"
put(wrong_key, "wrong-synthetic-password\n")
vim.env.ANSIBLE_VAULT_PASSWORD_FILE = wrong_key
saved = get(path)
change "wrong-credentials"
assert(not pcall(vim.cmd.write) and get(path) == saved, "wrong existing password file cannot silently rekey")
vim.env.ANSIBLE_VAULT_PASSWORD_FILE = key
local external = crypto("encrypt", "external: update\n")
change "conflicting-edit"
put(path, external)
assert(not pcall(vim.cmd.write), "external update must block save")
assert(get(path) == external and vim.bo.modified, "preserve external update")
edit(path)
assert(text() == "external: update", "reload encrypted change")

local failed = root .. "/failed.yml"
put(failed, ciphertext)
vim.env.ANSIBLE_VAULT_PASSWORD_FILE = root .. "/missing-key"
edit(failed)
assert(
  vim.bo.readonly and not vim.bo.modifiable and text():find("$ANSIBLE_VAULT;", 1, true),
  "failed decrypt stays protected"
)
assert(not pcall(vim.cmd, "write!"), "cannot write failed decrypt")
assert(get(failed) == ciphertext, "failed decrypt never changes disk")
vim.env.ANSIBLE_VAULT_PASSWORD_FILE = key
edit(failed)
assert(text() .. "\n" == original and not vim.bo.readonly and vim.bo.modifiable, "retry after environment fix")

local no_eol = root .. "/no-eol.yml"
put(no_eol, crypto("encrypt", "value: no-final-newline"))
edit(no_eol)
assert(not vim.bo.endofline, "preserve no EOL")
vim.cmd.write()
assert(crypto("decrypt", get(no_eol)) == "value: no-final-newline", "no extra EOL on save")
local dos = root .. "/dos.yml"
put(dos, crypto("encrypt", "one: 1\r\ntwo: 2\r\n"))
edit(dos)
assert(vim.bo.fileformat == "dos", "recognize CRLF")
vim.cmd.write()
assert(crypto("decrypt", get(dos)) == "one: 1\r\ntwo: 2\r\n", "preserve CRLF")

local key2 = root .. "/test-key-2"
put(key2, "second-synthetic-password\n")
vim.env.ANSIBLE_VAULT_PASSWORD_FILE = nil
vim.env.ANSIBLE_VAULT_IDENTITY_LIST = "dev@" .. key .. ",prod@" .. key2
vim.env.ANSIBLE_VAULT_ENCRYPT_IDENTITY = "prod"
local identities = root .. "/identities.yml"
put(identities, crypto("encrypt", original))
vim.env.ANSIBLE_VAULT_ENCRYPT_IDENTITY = "dev"
edit(identities)
assert(text() .. "\n" == original, "environment identities decrypt")
change "identity-test"
vim.cmd.write()
assert(
  get(identities):match "^%$ANSIBLE_VAULT;1%.2;AES256;prod",
  "preserve source identity despite a different environment default"
)
vim.env.ANSIBLE_VAULT_ENCRYPT_IDENTITY = nil
change "still-prod"
vim.cmd.write()
assert(
  get(identities):match "^%$ANSIBLE_VAULT;1%.2;AES256;prod",
  "preserve the file's identity without editor configuration"
)
local legacy = root .. "/legacy.yml"
put(legacy, ciphertext)
edit(legacy)
change "ambiguous"
assert(not pcall(vim.cmd.write) and get(legacy) == ciphertext, "untagged file with ambiguous identities fails safely")
vim.env.ANSIBLE_VAULT_IDENTITY_LIST = nil
vim.env.ANSIBLE_CONFIG = nil
put(root .. "/ansible.cfg", "[defaults]\nvault_password_file = " .. key .. "\n")
vim.cmd.cd(root)
local config_file = root .. "/from-config.yml"
put(config_file, crypto("encrypt", original))
edit(config_file)
assert(text() .. "\n" == original, "use Ansible project config")
vim.cmd.cd "/"
change "project-config"
vim.cmd.write()
vim.cmd.cd(root)
assert(crypto("decrypt", get(config_file)) == "password: project-config\n", "keep project cwd on save")
local link = root .. "/link.yml"
assert(uv.fs_symlink(config_file, link))
edit(link)
change "symlink-test"
vim.cmd.write()
assert(
  uv.fs_lstat(link).type == "link" and crypto("decrypt", get(config_file)) == "password: symlink-test\n",
  "preserve symlink"
)
local vault_undo = vim.fn.undofile(config_file)
assert(not uv.fs_stat(vault_undo), "no persistent plaintext undo")
assert(not uv.fs_stat(config_file .. "~"), "no backup side effects")
local export_append = root .. "/must-not-append.yml"
assert(not pcall(vim.cmd, "write >> " .. vim.fn.fnameescape(export_append)), "append blocked")
assert(not uv.fs_stat(export_append), "no plaintext append")
local scan = assert(uv.fs_scandir(root))
while true do
  local name, kind = uv.fs_scandir_next(scan)
  if not name then break end
  if kind == "file" then
    local contents = get(root .. "/" .. name)
    assert(not contents:find("password: synthetic-secret", 1, true), "plaintext leaked to file: " .. name)
  end
end
local plain = root .. "/plain.yml"
put(plain, "ordinary: yaml\n")
edit(plain)
assert(vim.bo.buftype == "" and not vim.b.ansible_vault, "ordinary YAML unaffected")
assert(#vim.fn.glob(root .. "/.nvim-vault-*", false, true) == 0, "temporary ciphertext cleaned")
print "PASS: real Ansible Vault open/save, env/config identities, failed decrypt/encrypt, conflicts, EOL, permissions, symlinks, export guards"
